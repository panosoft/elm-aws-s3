module Aws.S3.LowLevel
    exposing
        ( Config
        , ErrorResponse
        , GetObjectResponse
        , PutObjectResponse
        , ObjectExistsResponse
        , ObjectPropertiesResponse
        , objectExists
        , objectProperties
        , getObject
        , putObject
        )

{-| Low-level bindings to the AWS Simple Storage Service client for javascript.

These are useful in cases where you would like to chain tasks together and then produce a single command.

# S3
@docs Config, ErrorResponse, GetObjectResponse, PutObjectResponse, ObjectExistsResponse, ObjectPropertiesResponse, getObject, putObject, objectExists, objectProperties
-}

import Native.S3
import Task exposing (Task)
import Node.Buffer as Buffer exposing (..)


{-| ErrorResponse
-}
type alias ErrorResponse =
    { region : String
    , bucket : String
    , key : String
    , message : Maybe String
    , code : Maybe String
    , retryable : Maybe Bool
    , statusCode : Maybe Int
    , time : Maybe String
    }


{-| ObjectExistsResponse
-}
type alias ObjectExistsResponse =
    { region : String
    , bucket : String
    , key : String
    , exists : Bool
    }


{-| ObjectPropertiesResponse
-}
type alias ObjectPropertiesResponse =
    { region : String
    , bucket : String
    , key : String
    , contentType : String
    , contentLength : Int
    , contentEncoding : Maybe String
    , lastModified : Maybe String
    , deleteMarker : Maybe Bool
    , versionId : Maybe String
    , serverSideEncryption : String
    , storageClass : String
    }


{-| GetObjectResponse
-}
type alias GetObjectResponse =
    { region : String
    , bucket : String
    , key : String
    , body : Buffer
    , contentType : String
    , contentLength : Int
    , contentEncoding : Maybe String
    , lastModified : Maybe String
    , deleteMarker : Maybe Bool
    , versionId : Maybe String
    , serverSideEncryption : String
    , storageClass : String
    }


{-| PutObjectResponse
-}
type alias PutObjectResponse =
    { region : String
    , bucket : String
    , key : String
    , versionId : Maybe String
    , serverSideEncryption : String
    }


{-| Configuration for accessing S3.

From the [AWS SDK Documentation](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#constructor-property):

- `accessKeyId` - your AWS access key ID.
- `secretAccessKey` - your AWS secret access key.
- `serverSideEncryption` - true if Objects uploaded to S3 should be encrypted when stored, false if they should not be encrypted when stored.
- `debug` - log debug information if true.
-}
type alias Config =
    { accessKeyId : String
    , secretAccessKey : String
    , serverSideEncryption : Bool
    , debug : Bool
    }


{-| A low level method for determining the existence of an S3 object.

```
type Msg = ObjectExistsComplete (Result ErrorResponse ObjectExistsResponse)


objectExists config "<region>" "<bucket name>" "<object name>" ObjectExistsComplete
```
-}
objectExists : Config -> String -> String -> String -> Task ErrorResponse ObjectExistsResponse
objectExists =
    Native.S3.objectExists


{-| A low level method for determining the existence of an S3 object.
```
type Msg = ObjectPropertiesComplete (Result ErrorResponse ObjectPropertiesResponse)


objectProperties config "<region>" "<bucket name>" "<object name>" ObjectPropertiesComplete
```
-}
objectProperties : Config -> String -> String -> String -> Task ErrorResponse ObjectPropertiesResponse
objectProperties =
    Native.S3.objectProperties


{-| A low level method for getting an S3 object.
```
type Msg = GetObjectComplete (Result ErrorResponse GetObjectResponse)


getObject config "<region>" "<bucket name>" "<object name>" GetObjectComplete
```
-}
getObject : Config -> String -> String -> String -> Task ErrorResponse GetObjectResponse
getObject =
    Native.S3.getObject


{-| A low level method for uploading an S3 object.
```
type Msg = PutObjectComplete (Result ErrorResponse PutObjectResponse)


putObject config "<region>" "<bucket name>" "<object name>" "<object buffer>" PutObjectComplete
```
-}
putObject : Config -> String -> String -> String -> Buffer -> Task ErrorResponse PutObjectResponse
putObject =
    Native.S3.putObject
