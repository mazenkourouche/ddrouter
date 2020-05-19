# DDRouter

Deloitte Digital simple networking library.

## Getting Started

Integrate the library with your project using CocoaPods.

TODO: Integrate with trunk and provide integration examples

### Usage

Before using the library in your app (i.e. in your AppDelegate), call:

```
DDRouter.initialise(configuration: URLSessionConfiguration.default)
```

passing in a URLSessionConfiguration object - in most cases the URLSessionConfiguration.default configuration will be appropriate.

1. Define your endpoints in an enum, then implement the EndpointType protocol on your endpoint enum.
2. Define your APIs error model in a struct that implements APIErrorModelProtocol.
3. To make a request, create a Router object, passing in your endpoint type and API error model as generic parameters. Then call request() with the endpoint case as a parameter.
    - To have the API deserialise your response type correctly, return the call to request() from a function with it's return type defined as a Single<ResponseModel> where ResponseModel is your response model type.

## Licence

This project is licensed under the MIT License.
