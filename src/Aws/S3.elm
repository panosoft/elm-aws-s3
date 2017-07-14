module Aws.S3
    exposing
        ( config
        , objectExists
        , objectProperties
        , ObjectPropertiesResponse
        )

{-| AWS Simple Storage Service Api.

# S3
@docs config, objectExists, objectProperties, ObjectPropertiesResponse
-}

import Aws.S3.LowLevel as LowLevel exposing (Config, ObjectPropertiesResponse, objectExists, objectProperties)
import Task


{-| ObjectPropertiesResponse
-}
type alias ObjectPropertiesResponse =
    LowLevel.ObjectPropertiesResponse


{-| Create a configuration for accessing S3.

```
config = S3.config
    "AWS_REGION"
    "ACCESS_KEY_ID"
    "SECRET_ACCESS_KEY"
    serverSideEncryption

```
-}
config : String -> String -> String -> Bool -> Config
config =
    Config


{-| Test for S3 object existence.

From [AWS Documentation]():

```
type Msg =
    ObjectExistsComplete (Result String Bool)

objectExists config "<bucket name>" "<objectName>" ObjectExistsComplete
```
-}
objectExists : Config -> String -> String -> (Result String Bool -> msg) -> Cmd msg
objectExists config bucket key tagger =
    LowLevel.objectExists config bucket key
        |> Task.attempt tagger


{-| Get S3 object properties.

From [AWS Documentation]():

```
type Msg = ObjectPropertiesComplete (Result String ObjectPropertiesResponse)

objectProperties config "<bucket name>" "<objectName>" ObjectPropertiesComplete
```
-}
objectProperties : Config -> String -> String -> (Result String ObjectPropertiesResponse -> msg) -> Cmd msg
objectProperties config bucket key tagger =
    LowLevel.objectProperties config bucket key
        |> Task.attempt tagger
