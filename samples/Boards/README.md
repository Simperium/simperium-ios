# Boards

Boards is a simple web only app that uses Simperium to sync.
collaborate.

## Running Boards

- Create an app at [simperium.com](https://simperium.com/dashboard/)

- Note the application id and the API key.

- Create a user:

    `curl -H 'X-Simperium-API-Key: `*SIMPERIUM_API_KEY*`' -d
    '{"username":"boards@test.com", "password":"test"}'
    https://auth.simperium.com/1/`*SIMPERIUM_APP_ID*`/create/`

- Or sign in an existing user (you can use your simperium.com username/password):


    `curl -H 'X-Simperium-API-Key: `*SIMPERIUM_API_KEY*`' -d '{"username":"boards@test.com", "password":"test"}' https://auth.simperium.com/1/`*SIMPERIUM_APP_ID*`/authorize/


- Grab the `access_token` parameter from either the `create` or `authorize`
  call.

- Edit `js/boards.js`, replace _SIMPERIUM_APP_ID_ with your application id, and
  _SIMPERIUM_ACCESS_TOKEN_ with the access token.


This is a demo app that creates/edits data all in one Simperium user account for
anyone using the app. More secure ways to create these types of collaborative apps where
data is shared among different users are coming soon.

## Using Boards

- Click anywhere to create a pod, each pod holds some text. The web app
  automatically detects certain strings and renders the view accordingly. You
  can click 'x' to close any rendered view to get back to the text view.

- Images: Paste in an image link only and the image is rendered.

- Video: Paste in a Youtube or Vimeo link.

- Audio: Paste in a link to an .mp3/.wav/.ogg file to show an HTML5 audio player
  (if your browser supports it)

- Piechart: Type in an optional title, then 2 or more lines of the form: some
  text followed by a number, then two blank lines to render a chart.

- Map: Enter some text query, then "!map" on a line by itself at the end to show
  a Google Map.

- List: Enter two or more lines starting with "- " then a blank line to render
  a list with checkboxes.
