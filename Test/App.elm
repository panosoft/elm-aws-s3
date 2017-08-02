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
    , nonExistingS3KeyNameCopy : String
    , createdS3KeyName : Maybe String
    , createdS3KeyNameCopy : Maybe String
    , downloadedFileName : String
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
    | GetObjectExpectSucceed (Result ErrorResponse S3.GetObjectResponse)
    | WriteFileComplete String (Result String ())
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
   An existing test file whose contents will be used during testing.  This file must exist in the 'testFilesPath' directory or test will not run.
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
        -- create two non-existing S3 key names that will be used in testing and created on S3 during the test.
        -- once created, both keys will exist in the S3 test bucket until deleted manually.
        -- also a filename will be created that will be used to write a file to the  file system from a buffer retrieved from S3 by a getObject command.
        -- once this file is create in the file system, it will exist until manually deleted.
        |>
            (\_ ->
                (step Uuid.uuidGenerator <| initialSeed flags.seed)
                    |> (\( uuid, newSeed ) -> ( Uuid.toString uuid, newSeed ))
                    |> (\( uuidStr, newSeed ) ->
                            (replace All (regex <| escape "{{UUID}}") (\_ -> uuidStr) ("/testfile_{{UUID}}")
                                |> (\nonExistingS3KeyBaseName ->
                                        ( testFilesPath ++ nonExistingS3KeyBaseName ++ extension, testFilesPath ++ nonExistingS3KeyBaseName ++ "_COPY" ++ extension, downloadedFilesPath ++ nonExistingS3KeyBaseName ++ extension )
                                   )
                            )
                       )
            )
        |> (\( nonExistingS3KeyName, nonExistingS3KeyNameCopy, downloadedFileName ) ->
                (config "us-west-1" flags.accessKeyId flags.secretAccessKey True ((flags.debug == "debug") ? ( True, False )))
                    |> (\s3Config ->
                            ( (flags.dryrun == "--dry-run") ? ( True, False ), s3Config, nonExistingS3KeyName, nonExistingS3KeyNameCopy, downloadedFileName )
                       )
           )
        |> (\( dryrun, s3Config, nonExistingS3KeyName, nonExistingS3KeyNameCopy, downloadedFileName ) ->
                (dryrun
                    ?! ( \_ ->
                            ( Debug.log "Exiting App" "Reason: --dry-run specified"
                            , Debug.log "Parameters" { bucketName = s3BucketName, existingFileName = existingFileName, nonExistingS3KeyName = nonExistingS3KeyName, nonExistingS3KeyNameCopy = nonExistingS3KeyNameCopy, downloadedFileName = downloadedFileName }
                            , Debug.log "S3.Config" s3Config
                            )
                                |> always ()
                       , always ()
                       )
                    |> always
                        ({ s3Config = s3Config, maybeBuffer = Nothing, nonExistingS3KeyName = nonExistingS3KeyName, nonExistingS3KeyNameCopy = nonExistingS3KeyNameCopy, createdS3KeyName = Nothing, createdS3KeyNameCopy = Nothing, downloadedFileName = downloadedFileName }
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
    let
        processFailError error success =
            error.statusCode
                |?> (\statusCode ->
                        (statusCode == 404)
                            ?! ( (\_ -> success)
                               , (\_ -> update (TestsComplete <| Err "Unexpected error, error.statusCode should be 404") model)
                               )
                    )
                ?!= (\_ -> update (TestsComplete <| Err "Unexpected error, error.statusCode should be 404") model)

        getCreatedS3Key maybeCreatedS3KeyName =
            maybeCreatedS3KeyName
                |?> identity
                ?!= (\_ -> Debug.crash "BUG: model.createdS3KeyName should not be Nothing")
    in
        case msg of
            Exit _ ->
                model ! [ exitApp 1 ]

            ReadFileComplete filename (Err error) ->
                let
                    l =
                        Debug.log "ReadFileComplete Error"
                            { bucketName = s3BucketName, existingFileName = existingFileName, nonExistingS3KeyName = model.nonExistingS3KeyName, nonExistingS3KeyNameCopy = model.nonExistingS3KeyNameCopy, downloadedFileName = model.downloadedFileName, error = error }
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
                            { bucketName = s3BucketName, existingFileName = existingFileName, nonExistingS3KeyName = model.nonExistingS3KeyName, nonExistingS3KeyNameCopy = model.nonExistingS3KeyNameCopy, downloadedFileName = model.downloadedFileName, error = error }
                in
                    update (TestsComplete <| Err <| toString error) model

            InitComplete (Ok response) ->
                let
                    l =
                        Debug.log "InitComplete"
                            { bucketName = s3BucketName, existingFileName = existingFileName, nonExistingS3KeyName = model.nonExistingS3KeyName, nonExistingS3KeyNameCopy = model.nonExistingS3KeyNameCopy, downloadedFileName = model.downloadedFileName, exists = response.exists }
                in
                    response.exists
                        ?! ( (\_ -> update (TestsComplete <| Err (model.nonExistingS3KeyName ++ " should not exist")) model)
                           , (\_ -> model ! [ createRequest model.s3Config (ObjectProperties ObjectPropertiesExpectFail) s3BucketName model.nonExistingS3KeyName Nothing ])
                           )

            ObjectPropertiesExpectFail (Err error) ->
                let
                    message =
                        Debug.log "ObjectPropertiesExpectFail Error" error
                in
                    processFailError error
                        ( model, createRequest model.s3Config (GetObject GetObjectExpectFail) s3BucketName model.nonExistingS3KeyName Nothing )

            ObjectPropertiesExpectFail (Ok response) ->
                let
                    message =
                        Debug.log "ObjectPropertiesExpectFail" response
                in
                    update (TestsComplete <| Err (model.nonExistingS3KeyName ++ " should not exist")) model

            GetObjectExpectFail (Err error) ->
                let
                    message =
                        Debug.log "GetObjectExpectFail Error" error
                in
                    processFailError error <|
                        model
                            ! [ createRequest model.s3Config (CreateObject CreateObjectExpectSucceed) s3BucketName model.nonExistingS3KeyName model.maybeBuffer ]

            GetObjectExpectFail (Ok response) ->
                let
                    message =
                        Debug.log "GetObjectExpectFail" response
                in
                    update (TestsComplete <| Err ("GetObjectExpectFail " ++ model.nonExistingS3KeyName ++ " should not exist")) model

            CreateObjectExpectSucceed (Err error) ->
                let
                    message =
                        Debug.log "CreateObjectExpectSucceed Error" error
                in
                    update (TestsComplete <| Err <| toString error) model

            CreateObjectExpectSucceed (Ok response) ->
                let
                    message =
                        Debug.log "CreateObjectExpectSucceed" response
                in
                    ({ model | createdS3KeyName = Just response.key }
                        ! [ createRequest model.s3Config (CreateObject CreateObjectExpectFail) s3BucketName response.key model.maybeBuffer ]
                    )

            CreateObjectExpectFail (Err error) ->
                let
                    message =
                        Debug.log "CreateObjectExpectFail Error" error
                in
                    error.message
                        |?> (\message ->
                                (String.startsWith "createObject Overwrite Error:  Object exists (Bucket:") message
                                    ?! (( (\_ ->
                                            model
                                                ! [ createRequest model.s3Config (ObjectExists ObjectExistsExpectSucceed) s3BucketName (getCreatedS3Key model.createdS3KeyName) Nothing ]
                                          )
                                        , (\_ -> update (TestsComplete <| Err <| toString error) model)
                                        )
                                       )
                            )
                        ?!= (\_ -> update (TestsComplete <| Err <| toString error) model)

            CreateObjectExpectFail (Ok response) ->
                let
                    message =
                        Debug.log "CreateObjectExpectFail" response
                in
                    update (TestsComplete <| Err ("CreateObjectExpectFail " ++ (getCreatedS3Key model.createdS3KeyName) ++ " should not exist")) model

            ObjectExistsExpectSucceed (Err error) ->
                let
                    message =
                        Debug.log "ObjectExistsExpectSucceed Error" error
                in
                    update (TestsComplete <| Err <| toString error) model

            ObjectExistsExpectSucceed (Ok response) ->
                let
                    message =
                        Debug.log "ObjectExistsExpectSucceed" response
                in
                    response.exists
                        ?! ( (\_ ->
                                model
                                    ! [ createRequest model.s3Config (ObjectProperties ObjectPropertiesExpectSucceed) s3BucketName (getCreatedS3Key model.createdS3KeyName) Nothing ]
                             )
                           , (\_ -> update (TestsComplete <| Err (("ObjectExistsExpectSucceed " ++ getCreatedS3Key model.createdS3KeyName) ++ " should exist")) model)
                           )

            ObjectPropertiesExpectSucceed (Err error) ->
                let
                    message =
                        Debug.log "ObjectPropertiesExpectSucceed Error" error
                in
                    update (TestsComplete <| Err <| toString error) model

            ObjectPropertiesExpectSucceed (Ok response) ->
                let
                    message =
                        Debug.log "ObjectPropertiesExpectSucceed" response
                in
                    model
                        ! [ createRequest model.s3Config (CreateOrReplaceObject CreateOrReplaceObjectExpectSucceed) s3BucketName (getCreatedS3Key model.createdS3KeyName) model.maybeBuffer ]

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
                    model
                        ! [ createRequest model.s3Config (CreateOrReplaceObject FinalCreateOrReplaceObjectExpectSucceed) s3BucketName model.nonExistingS3KeyNameCopy model.maybeBuffer ]

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
                    ({ model | createdS3KeyNameCopy = Just response.key }
                        ! [ createRequest model.s3Config (GetObject GetObjectExpectSucceed) s3BucketName response.key Nothing ]
                    )

            GetObjectExpectSucceed (Err error) ->
                let
                    message =
                        Debug.log "GetObjectExpectSucceed Error" error
                in
                    update (TestsComplete <| Err <| toString error) model

            GetObjectExpectSucceed (Ok response) ->
                let
                    message =
                        Debug.log "GetObjectExpectSucceed"
                            { bucket = response.bucket
                            , key = response.key
                            , contentType = response.contentType
                            , contentLength = response.contentLength
                            , contentEncoding = response.contentEncoding
                            , lastModified = response.lastModified
                            , serverSideEncryption = response.serverSideEncryption
                            , storageClass = response.storageClass
                            }
                in
                    NodeBuffer.toString NodeEncoding.Ascii response.body
                        |??>
                            (\str ->
                                Debug.log "GetObjectExpectSucceed" ( response.bucket, response.key, ("Buffer (ascii): " ++ (String.left 80 str) ++ "  Buffer Length: " ++ (toString <| String.length str)) )
                                    |> (\_ ->
                                            ( model
                                            , NodeFileSystem.writeFile model.downloadedFileName response.body
                                                |> Task.mapError (\error -> NodeError.message error)
                                                |> Task.attempt (WriteFileComplete response.key)
                                            )
                                       )
                            )
                        ??= (\error -> update (TestsComplete <| Err <| NodeError.message error) model)

            WriteFileComplete filename (Err error) ->
                let
                    l =
                        Debug.log "WriteFileComplete Error" ( filename, error )
                in
                    update (TestsComplete <| Err error) model

            WriteFileComplete filename (Ok buffer) ->
                let
                    l =
                        Debug.log "WriteFileComplete" ("Filename: " ++ filename)
                in
                    update (TestsComplete <| Ok "") model

            TestsComplete (Err error) ->
                let
                    message =
                        Debug.log "Tests Completed with Error" error
                in
                    model ! [ exitApp 1 ]

            TestsComplete (Ok _) ->
                let
                    ll =
                        Debug.log "Tests Completed Successfully" ""
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
