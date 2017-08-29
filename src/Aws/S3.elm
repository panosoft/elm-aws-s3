module Aws.S3
    exposing
        ( config
        , objectExists
        , objectProperties
        , getObject
        , createObject
        , createOrReplaceObject
        , Config
        , ErrorResponse
        , GetObjectResponse
        , PutObjectResponse
        , ObjectExistsResponse
        , ObjectPropertiesResponse
        )

{-| AWS Simple Storage Service Api.

# S3
@docs config, getObject, createObject, createOrReplaceObject, objectExists, objectProperties, Config, ErrorResponse, GetObjectResponse, PutObjectResponse, ObjectExistsResponse, ObjectPropertiesResponse
-}

import Aws.S3.LowLevel as LowLevel exposing (Config, objectExists, objectProperties)
import Task
import Node.Buffer as Buffer exposing (..)
import Utils.Ops exposing (..)


{-| ErrorResponse
-}
type alias ErrorResponse =
    LowLevel.ErrorResponse


{-| ObjectExistsResponse
-}
type alias ObjectExistsResponse =
    LowLevel.ObjectExistsResponse


{-| ObjectPropertiesResponse
-}
type alias ObjectPropertiesResponse =
    LowLevel.ObjectPropertiesResponse


{-| GetObjectResponse
-}
type alias GetObjectResponse =
    LowLevel.GetObjectResponse


{-| PutObjectResponse
-}
type alias PutObjectResponse =
    LowLevel.PutObjectResponse


{-| Create a configuration for accessing S3.

```
config = S3.config
    "ACCESS_KEY_ID"
    "SECRET_ACCESS_KEY"
    serverSideEncryption
    debug

```
-}
config : String -> String -> Bool -> Bool -> Config
config =
    Config


{-| alias for LowLevel.Config.
-}
type alias Config =
    LowLevel.Config


{-| Test for S3 object existence.

From [AWS Documentation](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#headObject-property):

```
type Msg =
    ObjectExistsComplete (Result ErrorResponse ObjectExistsResponse)

objectExists config "<region>" "<bucket name>" "<object name>" ObjectExistsComplete
```
-}
objectExists : Config -> String -> String -> String -> (Result ErrorResponse ObjectExistsResponse -> msg) -> Cmd msg
objectExists config region bucket key tagger =
    log config region bucket key "objectExists"
        |> always (LowLevel.objectExists config region bucket key |> Task.attempt tagger)


{-| Get S3 object properties.

From [AWS Documentation](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#headObject-property):

```
type Msg = ObjectPropertiesComplete (Result ErrorResponse ObjectPropertiesResponse)

objectProperties config "<region>" "<bucket name>" "<object name>" ObjectPropertiesComplete
```
-}
objectProperties : Config -> String -> String -> String -> (Result ErrorResponse ObjectPropertiesResponse -> msg) -> Cmd msg
objectProperties config region bucket key tagger =
    log config region bucket key "objectProperties"
        |> always (LowLevel.objectProperties config region bucket key |> Task.attempt tagger)


{-| Get S3 object.

From [AWS Documentation](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#getObject-property):

```
type Msg = GetObjectComplete (Result ErrorResponse GetObjectResponse)

getObject config "<region>" "<bucket name>" "<object name>" GetObjectComplete
```
-}
getObject : Config -> String -> String -> String -> (Result ErrorResponse GetObjectResponse -> msg) -> Cmd msg
getObject config region bucket key tagger =
    log config region bucket key "getObject"
        |> always (LowLevel.getObject config region bucket key |> Task.attempt tagger)


{-| Create S3 object.

From [AWS Documentation](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#headObject-property) and
[AWS Documentation](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#putObject-property):

```
type Msg = PutObjectComplete (Result ErrorResponse PutObjectResponse)

createObject config "<region>" "<bucket name>" "<object name>" <object buffer> PutObjectComplete
```
-}
createObject : Config -> String -> String -> String -> Buffer -> (Result ErrorResponse PutObjectResponse -> msg) -> Cmd msg
createObject config region bucket key buffer tagger =
    log config region bucket key "createObject"
        |> always
            (LowLevel.objectExists config region bucket key
                |> Task.andThen
                    (\response ->
                        response.exists
                            ? ( Task.fail
                                    { region = region
                                    , bucket = bucket
                                    , key = key
                                    , message = Just ("createObject Overwrite Error:  Object exists (Bucket: " ++ response.bucket ++ " Object Key: " ++ response.key ++ ")")
                                    , code = Nothing
                                    , retryable = Nothing
                                    , statusCode = Nothing
                                    , time = Nothing
                                    }
                              , LowLevel.putObject config region bucket key buffer
                              )
                    )
                |> Task.attempt tagger
            )


{-| Create or Replace S3 object.

From [AWS Documentation](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#putObject-property):

```
type Msg = PutObjectComplete (Result ErrorResponse PutObjectResponse)

createOrReplaceObject config "<region>" "<bucket name>" "<object name>" <object buffer> PutObjectComplete
```
-}
createOrReplaceObject : Config -> String -> String -> String -> Buffer -> (Result ErrorResponse PutObjectResponse -> msg) -> Cmd msg
createOrReplaceObject config region bucket key buffer tagger =
    log config region bucket key "createOrReplaceObject"
        |> always (LowLevel.putObject config region bucket key buffer)
        |> Task.attempt tagger


log : Config -> String -> String -> String -> String -> String
log config region bucket key operation =
    config.debug ?! ( (\_ -> Debug.log "S3 --" ("Performing " ++ operation ++ " for Region: " ++ region ++ "   Bucket: " ++ bucket ++ "  Key: " ++ key)), always "" )
