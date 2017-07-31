port module App exposing (..)

--TODO Bug in 0.18 Elm compiler.  import is needed otherwise Json.Decode is not included in compiled js

import Json.Decode
import Task
import Aws.S3 as S3 exposing (..)
import Utils.Ops exposing (..)
import Node.Buffer as NodeBuffer exposing (Buffer)
import Node.FileSystem as NodeFileSystem exposing (readFile)
import Node.Error as NodeError exposing (..)
import Node.Encoding as NodeEncoding exposing (Encoding)
import Uuid
import Random.Pcg exposing (Seed, initialSeed, step)
import Regex exposing (..)


port exitApp : Float -> Cmd msg


port externalStop : (() -> msg) -> Sub msg


type alias Flags =
    { accessKeyId : String
    , secretAccessKey : String
    , debug : String
    , dryrun : String
    , seed : Int
    }


type alias Model =
    { config : S3.Config
    , maybeBuffer : Maybe Buffer
    , nonExistingS3KeyName : String
    }


type Msg
    = GetObjectComplete (Result ErrorResponse S3.GetObjectResponse)
    | CreateObjectComplete (Result ErrorResponse S3.PutObjectResponse)
    | CreateOrReplaceObjectComplete (Result ErrorResponse S3.PutObjectResponse)
    | ObjectExistsComplete (Result ErrorResponse S3.ObjectExistsResponse)
    | ObjectPropertiesComplete (Result ErrorResponse S3.ObjectPropertiesResponse)
    | InitComplete String (Result String Buffer)
    | Exit ()


s3BucketName : String
s3BucketName =
    "s3proxytest.panosoft.com"



{-
   The following three names (existingFileName, existingS3KeyName, and nonExistingS3KeyTemplate) should have the same extension (e. g. '.pdf').
-}
{- The name of a file that exists that will be read and whose contents will be used when creating a key  s3BucketName -}


extension : String
extension =
    ".pdf"


existingFileName : String
existingFileName =
    "testfiles/formFile" ++ extension



{- The name of an S3 key that exists in s3BucketName -}


existingS3KeyName : String
existingS3KeyName =
    "testfiles/formFile" ++ extension



{- The templated name of an S3 key that will not exist in s3BucketName once {{UUID}} is replace with a unique UUID by the App.
   Once the App runs successfully, the S3 key generated from the nonExistingS3KeyTemplate will exist in s3BucketName until it is deleted manually.
-}


nonExistingS3KeyTemplate : String
nonExistingS3KeyTemplate =
    "testfiles/testfiles1_{{UUID}}" ++ extension


init : Flags -> ( Model, Cmd Msg )
init flags =
    (flags.debug == "debug" || flags.debug == "")
        ?! ( always "", (\_ -> Debug.crash ("Invalid optional third parameter (" ++ flags.debug ++ "): Must be 'debug' if specified.\n\n" ++ usage)) )
        |> (\_ ->
                ((flags.dryrun == "--dry-run" || flags.dryrun == "")
                    ?! ( always "", (\_ -> Debug.crash ("Invalid optional fourth parameter (" ++ flags.dryrun ++ "): Must be '--dry-run' if specified.\n\n" ++ usage)) )
                )
           )
        |> (\_ ->
                (step Uuid.uuidGenerator <| initialSeed flags.seed)
                    |> (\( uuid, newSeed ) -> ( Uuid.toString uuid, newSeed ))
                    |> (\( uuidStr, newSeed ) ->
                            (replace All (regex <| escape "{{UUID}}") (\_ -> uuidStr) nonExistingS3KeyTemplate)
                       )
           )
        |> (\nonExistingS3KeyName ->
                (config "us-west-1" flags.accessKeyId flags.secretAccessKey True ((flags.debug == "debug") ? ( True, False )))
                    |> (\s3Config ->
                            ( (flags.dryrun == "--dry-run") ? ( True, False ), s3Config, nonExistingS3KeyName )
                       )
           )
        |> (\( dryrun, s3Config, nonExistingS3KeyName ) ->
                (dryrun
                    ?! ( \_ ->
                            ( Debug.log "Exiting App" "Reason: --dry-run specified"
                            , Debug.log "Parameters" { bucketName = s3BucketName, existingFileName = existingFileName, existingS3KeyName = existingS3KeyName, nonExistingS3KeyName = nonExistingS3KeyName }
                            , Debug.log "S3.Config" s3Config
                            )
                                |> always ()
                       , always ()
                       )
                    |> always
                        ({ config = s3Config, maybeBuffer = Nothing, nonExistingS3KeyName = nonExistingS3KeyName }
                            ! [ dryrun ? ( exitApp 0, readFileCmd existingFileName ) ]
                        )
                )
           )


usage : String
usage =
    "Usage: 'node main.js <accessKeyId> <secretAccessKey> debug --dry-run' \n     'debug' and '--dry-run' are optional\n"


readFileCmd : String -> Cmd Msg
readFileCmd filename =
    NodeFileSystem.readFile filename
        |> Task.mapError (\error -> NodeError.message error)
        |> Task.attempt (InitComplete filename)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Exit _ ->
            model ! [ exitApp 1 ]

        InitComplete filename (Err error) ->
            let
                l =
                    Debug.log "InitComplete Error"
                        { bucketName = s3BucketName, existingFileName = existingFileName, existingS3KeyName = existingS3KeyName, nonExistingS3KeyName = model.nonExistingS3KeyName, error = error }
            in
                model ! [ exitApp 1 ]

        InitComplete filename (Ok buffer) ->
            let
                l =
                    Debug.log "InitComplete"
                        { existingFileName = existingFileName, existingS3KeyName = existingS3KeyName, nonExistingS3KeyName = model.nonExistingS3KeyName }

                ll =
                    Debug.log "S3 Config" model.config
            in
                ({ model | maybeBuffer = Just buffer }
                    ! [ createRequest model ObjectExists s3BucketName model.nonExistingS3KeyName Nothing
                      , createRequest model ObjectExists s3BucketName existingS3KeyName Nothing
                      , createRequest model ObjectProperties s3BucketName existingS3KeyName Nothing
                      , createRequest model GetObject s3BucketName existingS3KeyName Nothing
                      ]
                )

        ObjectExistsComplete (Err error) ->
            let
                message =
                    Debug.log "ObjectExistsComplete Error" error
            in
                model ! []

        ObjectExistsComplete (Ok response) ->
            let
                message =
                    Debug.log "ObjectExistsComplete" response
            in
                response.exists ? ( model ! [], model ! [ createRequest model ObjectProperties s3BucketName model.nonExistingS3KeyName Nothing ] )

        ObjectPropertiesComplete (Err error) ->
            let
                message =
                    Debug.log "ObjectPropertiesComplete Error" error
            in
                model ! [ createRequest model GetObject s3BucketName model.nonExistingS3KeyName Nothing ]

        ObjectPropertiesComplete (Ok response) ->
            let
                message =
                    Debug.log "ObjectPropertiesComplete" response
            in
                model ! []

        GetObjectComplete (Err error) ->
            let
                message =
                    Debug.log "GetObjectComplete Error" error
            in
                model ! [ createRequest model CreateObject s3BucketName existingS3KeyName model.maybeBuffer ]

        GetObjectComplete (Ok response) ->
            NodeBuffer.toString NodeEncoding.Utf8 response.body
                |??>
                    (\str ->
                        Debug.log "GetObjectComplete"
                            ( response.bucket
                            , response.key
                            , ("Buffer: " ++ (String.left 80 str) ++ "  Buffer Length: " ++ (toString <| String.length str))
                            )
                    )
                ??= (\error -> Debug.log "GetObjectComplete Error" ( response.bucket, response.key, NodeError.message error ))
                |> always (model ! [])

        CreateObjectComplete (Err error) ->
            let
                message =
                    Debug.log "CreateObjectComplete Error" error
            in
                model ! [ createRequest model CreateObject s3BucketName model.nonExistingS3KeyName model.maybeBuffer ]

        CreateObjectComplete (Ok response) ->
            let
                message =
                    Debug.log "CreateObjectComplete" response
            in
                model ! [ createRequest model CreateOrReplaceObject s3BucketName model.nonExistingS3KeyName model.maybeBuffer ]

        CreateOrReplaceObjectComplete (Err error) ->
            let
                message =
                    Debug.log "CreateOrReplaceObjectComplete Error" error
            in
                model ! []

        CreateOrReplaceObjectComplete (Ok response) ->
            let
                message =
                    Debug.log "CreateOrReplaceObjectComplete" response
            in
                model ! [ exitApp 0 ]


main : Program Flags Model Msg
main =
    Platform.programWithFlags
        { init = init
        , update = update
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    externalStop Exit


type Request
    = ObjectExists
    | ObjectProperties
    | GetObject
    | CreateObject
    | CreateOrReplaceObject


createRequest : Model -> Request -> String -> String -> Maybe Buffer -> Cmd Msg
createRequest model requestType bucket key maybeBuffer =
    case requestType of
        ObjectExists ->
            S3.objectExists model.config bucket key ObjectExistsComplete

        ObjectProperties ->
            S3.objectProperties model.config bucket key ObjectPropertiesComplete

        GetObject ->
            S3.getObject model.config bucket key GetObjectComplete

        CreateObject ->
            maybeBuffer
                |?> (\buffer -> S3.createObject model.config bucket key buffer CreateObjectComplete)
                ?!= (\_ -> Debug.crash "createObject buffer is Nothing")

        CreateOrReplaceObject ->
            maybeBuffer
                |?> (\buffer -> S3.createOrReplaceObject model.config bucket key buffer CreateOrReplaceObjectComplete)
                ?!= (\_ -> Debug.crash "createOrReplaceObject buffer is Nothing")
