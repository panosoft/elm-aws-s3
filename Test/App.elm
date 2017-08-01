port module App exposing (..)

--TODO Bug in 0.18 Elm compiler.  import is needed otherwise Json.Decode is not included in compiled js

import Json.Decode
import Task
import Aws.S3 as S3 exposing (..)
import Utils.Ops exposing (..)
import Node.Buffer as NodeBuffer exposing (Buffer)
import Node.FileSystem as NodeFileSystem exposing (readFile, writeFile)
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
    { s3Config : S3.Config
    , maybeBuffer : Maybe Buffer
    , nonExistingS3KeyName : String
    , createdS3KeyName : Maybe String
    }


type Msg
    = ReadFileComplete String (Result String Buffer)
    | InitComplete (Result ErrorResponse S3.ObjectExistsResponse)
    | ObjectPropertiesExpectFail (Result ErrorResponse S3.ObjectPropertiesResponse)
    | GetObjectExpectFail (Result ErrorResponse S3.GetObjectResponse)
    | CreateObjectExpectSucceed (Result ErrorResponse S3.PutObjectResponse)
    | CreateObjectExpectFail (Result ErrorResponse S3.PutObjectResponse)
    | ObjectExistsExpectSucceed (Result ErrorResponse S3.ObjectExistsResponse)
    | ObjectPropertiesExpectSucceed (Result ErrorResponse S3.ObjectPropertiesResponse)
    | CreateOrReplaceObjectExpectSucceed (Result ErrorResponse S3.PutObjectResponse)
    | FinalCreateOrReplaceObjectExpectSucceed (Result ErrorResponse S3.PutObjectResponse)
    | TestsComplete (Result String String)
    | Exit ()



{-
   S3 bucket name to be used in the tests
-}


s3BucketName : String
s3BucketName =
    "s3proxytest.panosoft.com"



{-
   Extension for test files or key names
-}


extension : String
extension =
    ".pdf"



{-
   Directory from which test files will be read
-}


testFilesPath : String
testFilesPath =
    "testfiles"



{-
   Directory to which files downloaded by getObject will be created or overwritten if they already exist
-}


downloadedFilesPath : String
downloadedFilesPath =
    "downloadedFiles"



{-
   An existing test file whose contents will be used during testing
-}


existingFileName : String
existingFileName =
    testFilesPath ++ "/formFile" ++ extension


init : Flags -> ( Model, Cmd Msg )
init flags =
    (flags.debug == "debug" || flags.debug == "")
        ?! ( always "", (\_ -> Debug.crash ("Invalid optional third parameter (" ++ flags.debug ++ "): Must be 'debug' if specified.\n\n" ++ usage)) )
        |> (\_ ->
                ((flags.dryrun == "--dry-run" || flags.dryrun == "")
                    ?! ( always "", (\_ -> Debug.crash ("Invalid optional fourth parameter (" ++ flags.dryrun ++ "): Must be '--dry-run' if specified.\n\n" ++ usage)) )
                )
           )
        -- create a non-existing S3 key name that will be used in testing and created on S3 during the test.
        -- once created, it will exist in the test bucket until deleted manually.
        |>
            (\_ ->
                (step Uuid.uuidGenerator <| initialSeed flags.seed)
                    |> (\( uuid, newSeed ) -> ( Uuid.toString uuid, newSeed ))
                    |> (\( uuidStr, newSeed ) ->
                            (replace All (regex <| escape "{{UUID}}") (\_ -> uuidStr) ("testfiles/testfile_{{UUID}}" ++ extension))
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
                            , Debug.log "Parameters" { bucketName = s3BucketName, existingFileName = existingFileName, nonExistingS3KeyName = nonExistingS3KeyName }
                            , Debug.log "S3.Config" s3Config
                            )
                                |> always ()
                       , always ()
                       )
                    |> always
                        ({ s3Config = s3Config, maybeBuffer = Nothing, nonExistingS3KeyName = nonExistingS3KeyName, createdS3KeyName = Nothing }
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
        |> Task.attempt (ReadFileComplete filename)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Exit _ ->
            model ! [ exitApp 1 ]

        ReadFileComplete filename (Err error) ->
            let
                l =
                    Debug.log "ReadFileComplete Error"
                        { bucketName = s3BucketName, existingFileName = existingFileName, nonExistingS3KeyName = model.nonExistingS3KeyName, error = error }
            in
                update (TestsComplete <| Err error) model

        ReadFileComplete filename (Ok buffer) ->
            let
                l =
                    ( Debug.log "ReadFileComplete" ("Filename: " ++ filename)
                    , Debug.log "S3 Config" model.s3Config
                    )
            in
                ({ model | maybeBuffer = Just buffer } ! [ createRequest model.s3Config (ObjectExists InitComplete) s3BucketName model.nonExistingS3KeyName Nothing ])

        InitComplete (Err error) ->
            let
                l =
                    Debug.log "InitComplete Error"
                        { bucketName = s3BucketName, existingFileName = existingFileName, nonExistingS3KeyName = model.nonExistingS3KeyName, error = error }
            in
                update (TestsComplete <| Err <| toString error) model

        InitComplete (Ok response) ->
            let
                l =
                    Debug.log "InitComplete"
                        { bucketName = s3BucketName, existingFileName = existingFileName, nonExistingS3KeyName = model.nonExistingS3KeyName, exists = response.exists }
            in
                response.exists
                    ?! ( (\_ -> update (TestsComplete <| Err (model.nonExistingS3KeyName ++ " should not exist")) model)
                       , (\_ -> model ! [ createRequest model.s3Config (ObjectProperties ObjectPropertiesExpectFail) s3BucketName model.nonExistingS3KeyName Nothing ])
                       )

        ObjectPropertiesExpectFail (Err error) ->
            let
                message =
                    Debug.log "ObjectPropertiesComplete Error" error
            in
                model ! [ createRequest model.s3Config (GetObject GetObjectExpectFail) s3BucketName model.nonExistingS3KeyName Nothing ]

        ObjectPropertiesExpectFail (Ok response) ->
            let
                message =
                    Debug.log "ObjectPropertiesComplete" response
            in
                update (TestsComplete <| Err (model.nonExistingS3KeyName ++ " should not exist")) model

        GetObjectExpectFail (Err error) ->
            let
                message =
                    Debug.log "GetObjectExpectFail Error" error
            in
                update (TestsComplete <| Ok "") model

        -- model ! [ createRequest model.s3Config CreateObject s3BucketName model.nonExistingS3KeyName model.maybeBuffer ]
        GetObjectExpectFail (Ok response) ->
            update (TestsComplete <| Err ("GetObjectExpectFail " ++ model.nonExistingS3KeyName ++ " should not exist")) model

        -- NodeBuffer.toString NodeEncoding.Utf8 response.body
        --     |??>
        --         (\str ->
        --             Debug.log "GetObjectExpectFail" ( response.bucket, response.key, ("Buffer: " ++ (String.left 80 str) ++ "  Buffer Length: " ++ (toString <| String.length str)) )
        --         )
        --     ??= (\error -> Debug.log "GetObjectExpectFail Error" ( response.bucket, response.key, NodeError.message error ))
        --     |> always (model ! [])
        CreateObjectExpectSucceed (Err error) ->
            let
                message =
                    Debug.log "CreateObjectExpectSucceed Error" error
            in
                model ! []

        -- error.code
        --     |?> (\code ->
        --             (code == "NotFound")
        --                 ?! ( (\_ -> model ! [ createRequest model.s3Config (CreateOrReplaceObject CreateOrReplaceObjectExpectSucceed) s3BucketName model.nonExistingS3KeyName model.maybeBuffer ])
        --                    , (\_ -> update (TestsComplete <| Err ("Expecting error code of 'NotFound'.  Error " ++ toString error)) model)
        --                    )
        --         )
        --     ?!= (\_ -> update (TestsComplete <| Err ("Expecting error code of 'NotFound'.  Error " ++ toString error)) model)
        CreateObjectExpectSucceed (Ok response) ->
            let
                message =
                    Debug.log "CreateObjectExpectSucceed" response
            in
                ({ model | createdS3KeyName = Just response.key }
                    ! []
                 -- ! [ createRequest model.s3Config (CreateObject CreateObjectExpectFail) s3BucketName response.key model.maybeBuffer ]
                )

        CreateObjectExpectFail (Err error) ->
            let
                message =
                    Debug.log "CreateObjectExpectFail Error" error
            in
                model ! []

        CreateObjectExpectFail (Ok response) ->
            let
                message =
                    Debug.log "CreateObjectExpectFail" response
            in
                model ! []

        ObjectExistsExpectSucceed (Err error) ->
            let
                message =
                    Debug.log "ObjectExistsExpectSucceed Error" error
            in
                model ! []

        ObjectExistsExpectSucceed (Ok response) ->
            let
                message =
                    Debug.log "ObjectExistsExpectSucceed" response
            in
                response.exists ?! ( (\_ -> model ! []), (\_ -> model ! []) )

        ObjectPropertiesExpectSucceed (Err error) ->
            let
                message =
                    Debug.log "ObjectPropertiesExpectSucceed Error" error
            in
                model ! []

        ObjectPropertiesExpectSucceed (Ok response) ->
            let
                message =
                    Debug.log "ObjectPropertiesExpectSucceed" response
            in
                model ! []

        CreateOrReplaceObjectExpectSucceed (Err error) ->
            let
                message =
                    Debug.log "CreateOrReplaceObjectExpectSucceed Error" error
            in
                update (TestsComplete <| Err <| toString error) model

        CreateOrReplaceObjectExpectSucceed (Ok response) ->
            let
                message =
                    Debug.log "CreateOrReplaceObjectSucceed" response
            in
                model ! []

        -- model ! [ createRequest model.s3Config (CreateOrReplaceObject FinalCreateOrReplaceObjectComplete) s3BucketName model.nonExistingS3KeyName model.maybeBuffer ]
        FinalCreateOrReplaceObjectExpectSucceed (Err error) ->
            let
                message =
                    Debug.log "FinalCreateOrReplaceObjectExpectSucceed Error" error
            in
                update (TestsComplete <| Err <| toString error) model

        FinalCreateOrReplaceObjectExpectSucceed (Ok response) ->
            let
                message =
                    Debug.log "FinalCreateOrReplaceObjectExpectSucceed" response
            in
                update (TestsComplete <| Ok "") model

        TestsComplete (Err error) ->
            let
                message =
                    Debug.log "TestsComplete Error" error
            in
                model ! [ exitApp 1 ]

        TestsComplete (Ok _) ->
            let
                message =
                    Debug.log "TestsComplete" ""
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
    = ObjectExists (Result ErrorResponse ObjectExistsResponse -> Msg)
    | ObjectProperties (Result ErrorResponse ObjectPropertiesResponse -> Msg)
    | GetObject (Result ErrorResponse GetObjectResponse -> Msg)
    | CreateObject (Result ErrorResponse PutObjectResponse -> Msg)
    | CreateOrReplaceObject (Result ErrorResponse PutObjectResponse -> Msg)


createRequest : S3.Config -> Request -> String -> String -> Maybe Buffer -> Cmd Msg
createRequest s3Config requestType bucket key maybeBuffer =
    case requestType of
        ObjectExists tagger ->
            S3.objectExists s3Config bucket key tagger

        ObjectProperties tagger ->
            S3.objectProperties s3Config bucket key tagger

        GetObject tagger ->
            S3.getObject s3Config bucket key tagger

        CreateObject tagger ->
            maybeBuffer
                |?> (\buffer -> S3.createObject s3Config bucket key buffer tagger)
                ?!= (\_ -> Debug.crash "createObject buffer is Nothing")

        CreateOrReplaceObject tagger ->
            maybeBuffer
                |?> (\buffer -> S3.createOrReplaceObject s3Config bucket key buffer tagger)
                ?!= (\_ -> Debug.crash "createOrReplaceObject buffer is Nothing")
