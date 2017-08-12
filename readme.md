# Amazon Web Services Simple Storage Service (AWS S3) API for Elm

> An Elm library that provides access to certain AWS S3 functions.

> This library is built on top of the AWS SDK library for node, [aws-sdk](https://aws.amazon.com/sdk-for-node-js/), and supports a subset of the library's S3 functionality.

## Install

### Elm

Since the Elm Package Manager doesn't allow for Native code and this uses Native code, you have to install it directly from GitHub, e.g. via [elm-github-install](https://github.com/gdotdesign/elm-github-install) or some equivalent mechanism.

### Node modules

You'll also need to install the dependent node modules at the root of your Application Directory. See the example `package.json` for a list of the dependencies.

The installation can be done via `npm install` command.

### Test program

Purpose is to test the AWS S3 API that this library supports . Use `aBuild.sh` or `build.sh` to build it and run it with `node main` command.

## API

### S3 Config used in all commands

__Config__

```elm
type alias Config =
    { region : String
    , accessKeyId : String
    , secretAccessKey : String
    , serverSideEncryption : Bool
    , debug : Bool
    }
```

* `region` is the AWS region containing the S3 buckets being accessed or modified
* `accessKeyId` is your AWS accessKeyId
* `secretAccessKey` is your AWS secretAccessKey
* `serverSideEncryption` is `True` if created S3 objects should be encrypted on S3, `False` if encryption is not desired
* `debug` is `True` if debug messages should be logged, `False` if not debug messages should be logged


__Usage__

```elm
config : Config
config =
    { region = "<AWS region containing buckets>"
    , accessKeyId = "<your AWS accessKeyId>"
    , secretAccessKey = "<your AWS secretAccessKey>"
    , serverSideEncryption = True
    , debug = False
    }
```

### Commands

> Test for the existence of an S3 object

Check an S3 bucket for the existence of an S3 object using S3 SDK function [headObject](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#headObject-property).


```elm
objectExists : Config -> String -> String -> ObjectExistsCompleteTagger -> Cmd msg
objectExists config bucket key tagger =
```
__Usage__

```elm
objectExists config bucket key ObjectExistsComplete
```
* `ObjectExistsComplete` is your application's message to handle the different result scenarios
* `config` has fields used to configure S3 for the request
* `bucket` is the name of the S3 bucket that may contain the S3 object
* `key` is the name of the S3 object being checked

> Get the properties of an S3 object

Get the properties of an S3 object in an S3 bucket using S3 SDK function [headObject](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#headObject-property). Some properties may not be defined for an S3 object.

```elm
objectProperties : Config -> String -> String -> ObjectPropertiesCompleteTagger -> Cmd msg
objectProperties config bucket key tagger =
```
__Usage__

```elm
objectProperties config bucket key ObjectPropertiesComplete
```
* `ObjectPropertiesComplete` is your application's message to handle the different result scenarios
* `config` has fields used to configure S3 for the request
* `bucket` is the name of the S3 bucket that may contain the S3 object
* `key` is the name of the S3 object whose properties are being retrieved

> Retrieve an S3 object and its properties

Retrieve an S3 object and its properties from an S3 bucket using S3 SDK function [getObject](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#getObject-property).

```elm
getObject : Config -> String -> String -> GetObjectCompleteTagger -> Cmd msg
getObject config bucket key tagger =
```
__Usage__

```elm
getObject config bucket key GetObjectComplete
```
* `GetObjectComplete` is your application's message to handle the different result scenarios
* `config` has fields used to configure S3 for the request
* `bucket` is the name of the S3 bucket that may contain the S3 object
* `key` is the name of the S3 object being retrieved

> Create an S3 object in an S3 bucket

Create an S3 object in an S3 bucket. This will cause an error if the S3 object already exists. This function uses `Buffer` defined in [elm-node/core](https://github.com/elm-node/core), and S3 SDK functions [headObject](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#headObject-property), and [putObject](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#putObject-property).

```elm
createObject : Config -> String -> String -> Buffer -> CreateObjectCompleteTagger -> Cmd msg
createObject config bucket key body tagger =
```
__Usage__

```elm
createObject config bucket key body CreatObjectComplete
```
* `CreateObjectComplete` is your application's message to handle the different result scenarios
* `config` has fields used to configure S3 for the request
* `bucket` is the name of the S3 bucket that may contain the S3 object
* `key` is the name of the S3 object being created
* `body` is a buffer containing the contents of S3 object being created

> Create or replace an S3 object in an S3 bucket

Create an S3 object in an S3 bucket, or replace an S3 object in an S3 bucket if the S3 object already exists. This function uses `Buffer` defined in [elm-node/core](https://github.com/elm-node/core), and S3 SDK function [putObject](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/S3.html#putObject-property).

```elm
createOrReplaceObject : Config -> String -> String -> Buffer -> CreateOrReplaceObjectCompleteTagger -> Cmd msg
createOrReplaceObject config bucket key body tagger =
```
__Usage__

```elm
createOrReplaceObject config bucket key body CreateOrReplaceObjectComplete
```
* `CreateOrReplaceObjectComplete` is your application's message to handle the different result scenarios
* `config` has fields used to configure S3 for the request
* `bucket` is the name of the S3 bucket that may contain the S3 object
* `key` is the name of the S3 object being created or replaced
* `body` is a buffer containing the contents of S3 object being created or replaced


### Subscriptions

> There are no subscriptions.

### Types

#### ObjectExistsTagger

Returns an Elm Result indicating a successful call to `objectExists` or an S3 error.

```elm
type alias ObjectExistsTagger msg =
    ( Result ErrorResponse ObjectExistsResponse ) -> msg
```

__Usage__

```elm
ObjectExistsComplete (Ok response) ->
    let
        l =
            Debug.log "ObjectExistsComplete" response
    in
    model ! []

ObjectExistsComplete (Err error) ->
    let
        l =
            Debug.log "ObjectExistsComplete Error" error
    in
        model ! []
```

#### ObjectPropertiesTagger

Returns an Elm Result indicating a successful call to `objectProperties` or an S3 error.

```elm
type alias ObjectPropertiesTagger msg =
    ( Result ErrorResponse ObjectPropertiesResponse ) -> msg
```

__Usage__

```elm
ObjectPropertiesComplete (Ok response) ->
    let
        l =
            Debug.log "ObjectPropertiesComplete" response
    in
    model ! []

ObjectPropertiesComplete (Err error) ->
    let
        l =
            Debug.log "ObjectPropertiesComplete Error" error
    in
        model ! []
```

#### GetObjectTagger

Returns an Elm Result indicating a successful call to `getObject` or an S3 error.

```elm
type alias GetObjectTagger msg =
    ( Result ErrorResponse GetObjectResponse ) -> msg
```

__Usage__

```elm
GetObjectComplete (Ok response) ->
    let
        l =
            Debug.log "GetObjectComplete" response
    in
    model ! []

GetObjectComplete (Err error) ->
    let
        l =
            Debug.log "GetObjectComplete Error" error
    in
        model ! []
```

#### CreateObjectTagger

Returns an Elm Result indicating a successful call to `createObject` or an S3 error.

```elm
type alias CreateObjectTagger msg =
    ( Result ErrorResponse CreateObjectResponse ) -> msg
```

__Usage__

```elm
CreateObjectComplete (Ok response) ->
    let
        l =
            Debug.log "CreateObjectComplete" response
    in
    model ! []

CreateObjectComplete (Err error) ->
    let
        l =
            Debug.log "CreateObjectComplete Error" error
    in
        model ! []
```

#### CreateOrReplaceObjectTagger

Returns an Elm Result indicating a successful call to `createOrReplaceObject` or an S3 error.

```elm
type alias CreateOrReplaceObjectTagger msg =
    ( Result ErrorResponse CreateOrReplaceObjectResponse ) -> msg
```

__Usage__

```elm
CreateOrReplaceObjectComplete (Ok response) ->
    let
        l =
            Debug.log "CreateOrReplaceObjectComplete" response
    in
    model ! []

CreateOrReplaceObjectComplete (Err error) ->
    let
        l =
            Debug.log "CreateOrReplaceObjectComplete Error" error
    in
        model ! []
```
#### ErrorResponse

Error returned from all S3 operations.

```elm
type alias ErrorResponse =
    { bucket : String
    , key : String
    , message : Maybe String
    , code : Maybe String
    , retryable : Maybe Bool
    , statusCode : Maybe Int
    , time : Maybe String
    , region : Maybe String
    }
```

* `bucket` is the name of the S3 bucket used in the operation
* `key` is the name of the S3 object used in the operation
* `message` is the error message
* `code` is the AWS return code
* `retryable` indicates if the AWS operation is retryable
* `statusCode` is the HTTP code
* `time` is the time the error occurred
* `region` is the AWS region used in the operation

#### ObjectExistsResponse

Successful return from `objectExists` operation.

```elm
type alias ObjectExistsResponse =
    { bucket : String
    , key : String
    , exists : Bool
    }
```

* `bucket` is the name of the S3 bucket used in the operation
* `key` is the name of the S3 object used in the operation
* `exists` is True if the S3 object exists in the S3 bucket and False otherwise

#### ObjectPropertiesResponse

Successful return from `objectProperties` operation.

```elm
type alias ObjectPropertiesResponse =
    { bucket : String
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
```

* `bucket` is the name of the S3 bucket used in the operation
* `key` is the name of the S3 object used in the operation
* `contentType` is the content type of the S3 object
* `contentLength` is the length of the S3 object
* `contentEncoding` is the content encoding of the S3 object
* `lastModified` is the last modified time of the S3 object
* `deleteMarker` is True if the S3 object is versioned and the latest version has been deleted, False otherwise
* `versionId` is the version Id of the S3 object if it is versioned
* `serverSideEncryption` is the encryption type of the S3 object if it is encrypted on S3
* `storageClass` is the storageClass type of the S3 object

#### GetObjectResponse

Successful return from `getObject` operation.

```elm
type alias GetObjectResponse =
    { bucket : String
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
```

* `bucket` is the name of the S3 bucket used in the operation
* `key` is the name of the S3 object used in the operation
* `body` is buffer containing the contents of the S3 object

    (see `ObjectPropertiesResponse` for definition of the remaining fields)

#### PutObjectResponse

Successful return from `createObject` or `createOrReplaceObject` operations.

```elm
type alias PutObjectResponse =
    { bucket : String
    , key : String
    , versionId : Maybe String
    , serverSideEncryption : String
    }
```

* `bucket` is the name of the S3 bucket used in the operation
* `key` is the name of the S3 object used in the operation
* `versionId` is the version Id S3 object it is versioned
* `serverSideEncryption` is the encryption type of the S3 object if it has been encrypted on S3
