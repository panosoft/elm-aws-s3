module Aws.S3
    exposing
        ( config
        , objectExists
        , objectProperties
        , getObject
        , createObject
        , createOrReplaceObject
        , GetObjectResponse
        , PutObjectResponse
        , ObjectExistsResponse
        , ObjectPropertiesResponse
        )

{-| AWS Simple Storage Service Api.

# S3
@docs config, getObject, createObject, createOrReplaceObject, objectExists, objectProperties, GetObjectResponse, PutObjectResponse, ObjectExistsResponse, ObjectPropertiesResponse
-}

import Aws.S3.LowLevel as LowLevel exposing (Config, objectExists, objectProperties)
import Task
import Node.Buffer as Buffer exposing (..)
import Utils.Ops exposing (..)


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
    "AWS_REGION"
    "ACCESS_KEY_ID"
    "SECRET_ACCESS_KEY"
    serverSideEncryption
    debug

```
-}
config : String -> String -> String -> Bool -> Bool -> Config
config =
    Config


{-| Test for S3 object existence.

From [AWS Documentation]():

```
type Msg =
    ObjectExistsComplete (Result String ObjectExistsResponse)

objectExists config "<bucket name>" "<object name>" ObjectExistsComplete
```
-}
objectExists : Config -> String -> String -> (Result String ObjectExistsResponse -> msg) -> Cmd msg
objectExists config bucket key tagger =
    log config bucket key "objectExists"
        |> always (LowLevel.objectExists config bucket key |> Task.attempt tagger)


{-| Get S3 object properties.

From [AWS Documentation]():

```
type Msg = ObjectPropertiesComplete (Result String ObjectPropertiesResponse)

objectProperties config "<bucket name>" "<object name>" ObjectPropertiesComplete
```
-}
objectProperties : Config -> String -> String -> (Result String ObjectPropertiesResponse -> msg) -> Cmd msg
objectProperties config bucket key tagger =
    log config bucket key "objectProperties"
        |> always (LowLevel.objectProperties config bucket key |> Task.attempt tagger)


{-| Get S3 object.

From [AWS Documentation]():

```
type Msg = GetObjectComplete (Result String GetObjectResponse)

getObject config "<bucket name>" "<object name>" GetObjectComplete
```
-}
getObject : Config -> String -> String -> (Result String GetObjectResponse -> msg) -> Cmd msg
getObject config bucket key tagger =
    log config bucket key "getObject"
        |> always (LowLevel.getObject config bucket key |> Task.attempt tagger)


{-| Create S3 object.

From [AWS Documentation]():

```
type Msg = PutObjectComplete (Result String PutObjectResponse)

createObject config "<bucket name>" "<object name>" <object buffer> PutObjectComplete
```
-}
createObject : Config -> String -> String -> Buffer -> (Result String PutObjectResponse -> msg) -> Cmd msg
createObject config bucket key buffer tagger =
    log config bucket key "createObject"
        |> always
            (LowLevel.objectExists config bucket key
                |> Task.andThen
                    (\response ->
                        response.exists
                            ? ( Task.fail
                                    ("createObject Overwrite Error:  Object exists (Bucket: " ++ response.bucket ++ " Object Key: " ++ response.key ++ ")")
                              , LowLevel.putObject config bucket key buffer
                              )
                    )
                |> Task.attempt tagger
            )


{-| Create or Replace S3 object.

From [AWS Documentation]():

```
type Msg = PutObjectComplete (Result String PutObjectResponse)

createOrReplaceObject config "<bucket name>" "<object name>" <object buffer> PutObjectComplete
```
-}
createOrReplaceObject : Config -> String -> String -> Buffer -> (Result String PutObjectResponse -> msg) -> Cmd msg
createOrReplaceObject config bucket key buffer tagger =
    log config bucket key "createOrReplaceObject"
        |> always (LowLevel.putObject config bucket key buffer)
        |> Task.attempt tagger


log : Config -> String -> String -> String -> String
log config bucket key operation =
    config.debug ? ( (Debug.log "S3 --" ("Performing " ++ operation ++ " for Bucket: " ++ bucket ++ "  Key: " ++ key)), "" )
