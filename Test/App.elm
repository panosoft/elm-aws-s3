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


port exitApp : Float -> Cmd msg


port externalStop : (() -> msg) -> Sub msg


type alias Flags =
    { accessKeyId : String
    , secretAccessKey : String
    , debug : String
    }


type alias Model =
    { config : S3.Config
    , maybeBuffer : Maybe Buffer
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


existingFileName : String
existingFileName =
    "testfiles/formFile.pdf"


existingS3KeyName : String
existingS3KeyName =
    "testfiles/formFile.pdf"


nonExistingS3KeyName : String
nonExistingS3KeyName =
    "testfiles/testfiles1.pdf"


init : Flags -> ( Model, Cmd Msg )
init flags =
    config "us-west-1" flags.accessKeyId flags.secretAccessKey True ((flags.debug == "debug") ? ( True, False ))
        |> (\config ->
                ({ config = config, maybeBuffer = Nothing } ! [ readFileCmd existingFileName ])
           )


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
                    Debug.log "InitComplete Error" ( filename, error )
            in
                model ! [ exitApp 1 ]

        InitComplete filename (Ok buffer) ->
            let
                l =
                    Debug.log "InitComplete" filename

                ll =
                    Debug.log "S3 Config" model.config
            in
                { model | maybeBuffer = Just buffer }
                    |> (\model ->
                            (model
                                ! [ createRequest model ObjectExists s3BucketName nonExistingS3KeyName Nothing
                                  , createRequest model ObjectExists s3BucketName existingS3KeyName Nothing
                                  , createRequest model ObjectProperties s3BucketName existingS3KeyName Nothing
                                  , createRequest model GetObject s3BucketName existingS3KeyName Nothing
                                  ]
                            )
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
                response.exists ? ( model ! [], model ! [ createRequest model ObjectProperties s3BucketName nonExistingS3KeyName Nothing ] )

        ObjectPropertiesComplete (Err error) ->
            let
                message =
                    Debug.log "ObjectPropertiesComplete Error" error
            in
                model ! [ createRequest model GetObject s3BucketName nonExistingS3KeyName Nothing ]

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
                model ! [ createRequest model CreateObject s3BucketName nonExistingS3KeyName model.maybeBuffer ]

        CreateObjectComplete (Ok response) ->
            let
                message =
                    Debug.log "CreateObjectComplete" response
            in
                model ! [ createRequest model CreateOrReplaceObject s3BucketName nonExistingS3KeyName model.maybeBuffer ]

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
                model ! [ exitApp 1 ]


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
