module Aws.S3.LowLevel
    exposing
        ( Config
        , ObjectPropertiesResponse
        , objectExists
        , objectProperties
        )

{-| Low-level bindings to the [AWS Simple Storage Service]() client for javascript.

These are useful in cases where you would like to chain tasks together and then produce a single command.

# S3
@docs Config, ObjectPropertiesResponse, objectExists, objectProperties
-}

import Native.S3
import Task exposing (Task)


{-| ObjectPropertiesResponse
-}
type alias ObjectPropertiesResponse =
    { contentType : String
    , contentLength : Int
    , contentEncoding : Maybe String
    , serverSideEncryption : String
    }


{-| Configuration for accessing S3.

From the [AWS SDK Documentation]() and [AWS S3 Documentation]():

- `region` - the region to send service requests to. See AWS.S3.region for more information.
- `accessKeyId` - your AWS access key ID.
- `secretAccessKey` - your AWS secret access key.
- `serverSideEncryption` - true if Objects uploaded to S3 should be encrypted when stored, false if they should not be encrypted when stored.
-}
type alias Config =
    { region : String
    , accessKeyId : String
    , secretAccessKey : String
    , serverSideEncryption : Bool
    }


{-| A low level method for determining the existence of an S3 object.

```
type Msg = ObjectExistsComplete (Result String Bool)


objectExists config "<bucket name>" "<objectName" ObjectExistsComplete
```
-}
objectExists : Config -> String -> String -> Task String Bool
objectExists =
    Native.S3.objectExists


{-| A low level method for determining the existence of an S3 object.
```
type Msg = ObjectPropertiesComplete (Result String ObjectPropertiesResponse)


objectProperties config "<bucket name>" "<objectName" ObjectPropertiesComplete
```
-}
objectProperties : Config -> String -> String -> Task String ObjectPropertiesResponse
objectProperties =
    Native.S3.objectProperties
