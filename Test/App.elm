port module App exposing (..)

--TODO Bug in 0.18 Elm compiler.  import is needed otherwise Json.Decode is not included in compiled js

import Json.Decode
import Task
import Aws.S3 as S3 exposing (..)
import Aws.S3.LowLevel as S3LowLevel exposing (..)
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
    { config : S3LowLevel.Config }


type Msg
    = GetObjectComplete (Result String S3.GetObjectResponse)
    | PutObjectComplete (Result String S3.PutObjectResponse)
    | ObjectExistsComplete (Result String S3.ObjectExistsResponse)
    | ObjectPropertiesComplete (Result String S3.ObjectPropertiesResponse)
    | ReadFileComplete String (Result String Buffer)
    | Exit ()


init : Flags -> ( Model, Cmd Msg )
init flags =
    S3.config "us-west-1" flags.accessKeyId flags.secretAccessKey True ((flags.debug == "debug") ? ( True, False ))
        |> (\config ->
                ({ config = config } ! [ readFileCmd "testfiles/testfile1.txt" ])
           )


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

        GetObjectComplete (Err error) ->
            let
                message =
                    Debug.log "GetObjectComplete Error" error
            in
                model ! []

        GetObjectComplete (Ok data) ->
            NodeBuffer.toString NodeEncoding.Utf8 data.body
                |??>
                    (\str ->
                        Debug.log "GetObjectComplete" ("Buffer: " ++ (String.left 80 str) ++ "  Buffer Length: " ++ (toString <| String.length str))
                    )
                ??= (\error -> Debug.log "GetObjectComplete Error" NodeError.message error)
                |> always (model ! [])

        PutObjectComplete (Err error) ->
            let
                message =
                    Debug.log "PutObjectComplete Error" error
            in
                model ! []

        PutObjectComplete (Ok data) ->
            let
                message =
                    Debug.log "PutObjectComplete" data
            in
                model ! []

        ObjectExistsComplete (Err error) ->
            let
                message =
                    Debug.log "ObjectExistsComplete Error" error
            in
                model ! []

        ObjectExistsComplete (Ok exists) ->
            let
                message =
                    Debug.log "ObjectExistsComplete" exists
            in
                model ! []

        ObjectPropertiesComplete (Err error) ->
            let
                message =
                    Debug.log "ObjectPropertiesComplete Error" error
            in
                model ! []

        ObjectPropertiesComplete (Ok properties) ->
            let
                message =
                    Debug.log "ObjectPropertiesComplete" properties
            in
                model ! []

        ReadFileComplete filename (Err error) ->
            let
                l =
                    Debug.log "ReadFileComplete Error" ( filename, error )
            in
                model ! [ exitApp 1 ]

        ReadFileComplete filename (Ok buffer) ->
            let
                l =
                    Debug.log "ReadFileComplete" filename
            in
                model
                    ! [ S3.objectExists model.config "s3proxytest.panosoft.com" "testfiles/testfile.txt" ObjectExistsComplete
                      , S3.objectProperties model.config "s3proxytest.panosoft.com" "testfiles/testfile.txt" ObjectPropertiesComplete
                      , S3.objectExists model.config "s3proxytest.panosoft.com" "testfiles/formFile.pdf" ObjectExistsComplete
                      , S3.objectProperties model.config "s3proxytest.panosoft.com" "testfiles/formFile.pdf" ObjectPropertiesComplete
                      , S3.getObject model.config "s3proxytest.panosoft.com" "testfiles/formFile.pdf" GetObjectComplete
                      , S3.createObject model.config "s3proxytest.panosoft.com" filename buffer PutObjectComplete
                      ]


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
