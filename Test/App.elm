port module App exposing (..)

-- Needed otherwise Json.Decode is not included in compiled js

import Json.Decode
import Aws.S3 as S3 exposing (..)


port exitApp : Float -> Cmd msg


port externalStop : (() -> msg) -> Sub msg


type alias Flags =
    { accessKeyId : String
    , secretAccessKey : String
    }


type alias Model =
    {}


model : Model
model =
    {}


type Msg
    = ObjectExistsComplete (Result String Bool)
    | ObjectPropertiesComplete (Result String S3.ObjectPropertiesResponse)
    | Exit ()


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        config =
            S3.config "us-west-1" flags.accessKeyId flags.secretAccessKey True
    in
        model
            ! [ S3.objectExists config "s3proxytest.panosoft.com" "testfiles/formFile.pdf" ObjectExistsComplete
              , S3.objectProperties config "s3proxytest.panosoft.com" "testfiles/formFile.pdf" ObjectPropertiesComplete
              ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Exit _ ->
            model ! [ exitApp 1 ]

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
