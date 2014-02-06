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
                                                                                
This tutorial covers basic connectivity features of the AddLive platform..     
                                                                                
The sample application implemented, initializes the platform and sets up local
preview as per Tutorial 2. It allows also user to connect to a media scope with
a hardcoded id.
           
## Tutorial 4 - Speakers' activity.

This tutorial covers basic use of the [ALService monitorSpeakrsActivity] API. 


## Tutorial 5 - TBD

## Tutorial 6 - AVAudioPlayer

This tutorial shows how to use AVFoundation AVAudioPlayer class in the presence
of the AddLive SDK.

## License

All code examples provided within this repository are available under the
MIT-License. For more details, please refer to the LICENSE.md
