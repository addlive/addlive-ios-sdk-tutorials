# AddLive iOS SDK Tutorials

This repository contains several objectve-C project showcasing the basics
of the AddLive iOS SDK functionality.

For more details please refer to AddLive home page: http://www.addlive.com.

Please note that tutorials require at least version v3.0.0.27 of the AddLive
SDK. This is due to the migration from libstdc++ and gnu runtime to
libc++ and -std=c++11 runtime.

## Tutorial 1 - platform init

This tutorial covers platform initialization and calling service methods.

The sample application showcasing the functionality simply loads the SDK, calls
the getVersion method and displays the version string in a label.

## Tutorial 2 - local preview

This tutorial covers devices handling, local preview control and rendering.

The sample application implemented, initializes the platform, sets up camera
devices, starts local video and renders it using ALVideoView components
provided.

## Tutorial 3 - Basic connectivity

This tutorial covers basic connectivity features of the AddLive platform.

The sample application implemented, initializes the platform and sets up local
preview as per Tutorial 2. It allows also user to connect to a media scope with
a hardcoded id.

## Tutorial 4 - Speakers' activity

This tutorial covers basic use of the [ALService monitorSpeakrsActivity] API.

The sample application implements the listener onSpeechActivity which receives
the user id and activity of each user in the session.

## Tutorial 5 - Conference App

This tutorial covers implementation of more advanced video conferencing
application and employs all of the connectivity-related features of the
AddLive SDK.

The sample application renders each new user within a scroll view allowing you
to swipe between the video feed in the session.

## Tutorial 6 - AVAudioPlayer

This tutorial shows how to use AVFoundation AVAudioPlayer class in the presence
of the AddLive SDK.

## Tutorial 7 - Screen Sharing

This tutorial provides a sample implementation of screen sharing functionality

The sample application renders the screen shared within the App. Please notice
that you will only be able to receive the screen share streaming of an user
within your session you will not be able to share your screeen as it's not
supported on mobiles.

## Tutorial 8 - Conference App & Speaking person video

This tutorial provides a sample implementation of one of the many uses you can
give to the speechActivity feature.

The sample application renders only the video of the speaking person and we
achieve this making use of the onSpeechActivity listener and it's parameters.

## License

All code examples provided within this repository are available under the
MIT-License. For more details, please refer to the LICENSE.md
