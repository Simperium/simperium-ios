# Simplesmash

Simplesmash is a demo of using Simperium to sync a player along with multiple
devices' viewport positions between the web and iOS.

## Simplesmash for iOS

- Create an app at [simperium.com](https://simperium.com/dashboard/)

- Note the application id and the API key.

- Launch Xcode and open the Simplesmash project file `ios/Simplesmash.xcodeproj`

- Open `ios/Classes/SimplesmashAppDelegate.m` and replace _SIMPERIUM_APP_ID_ and
  _SIMPERIUM_API_KEY_ with the details from the application you created.

- Choose the appropriate target in the upper left (Simplesmash > iPhone or iPad)
  then Build and Run

- The default sign in screen is shown, you can either create a new user or you
  can use your simperium.com username/password.

## Simplesmash for web

- Using the same application id and API key, you'll want to get an access token
  for the same user that is signed in on iOS.

- Get an access token:

    curl -H 'X-Simperium-API-Key: SIMPERIUM_API_KEY' -d
    '{"username":"same as above", "password":"same as above"}'
    https://auth.simperium.com/1/SIMPERIUM_APP_ID/authorize/

- Edit `web/app.js`, replace _SIMPERIUM_APP_ID_ with your application id, and
  _SIMPERIUM_ACCESS_TOKEN_ with the access token.

- Deploy to a web server or you can run locally using python. From the
  `Simplesmash\web`
  directory:

    python -m SimpleHTTPServer 8000

## Simplesmash service


