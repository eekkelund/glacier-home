import QtQuick 2.6

import org.nemomobile.lipstick 0.1
import org.nemomobile.devicelock 1.0
import org.nemomobile.configuration 1.0
import "notifications"


Image {
    id: lockScreen
    source: lockScreenWallpaper.value
    fillMode: Image.PreserveAspectCrop

    property bool displayOn

    ConfigurationValue{
        id: lockScreenWallpaper
        key: "/home/glacier/lockScreen/wallpaperImage"
        defaultValue: "/usr/share/lipstick-glacier-home-qt5/qml/images/graphics-wallpaper-home.jpg"
    }
    LockscreenClock {
        id: clock
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
    }

    // Swipes on the lockscreen
    MouseArea {
        id:mouseArea

        property bool gestureStarted: false
        property string gesture: ""
        property int startX
        property int threshold: Theme.itemHeightHuge * 2
        property int swipeDistance
        property string action: ""

        anchors.fill: parent

        onPressed: {
            startX = mouseX;
        }
        onMouseXChanged: {
            // Checks which was it left or right swipe
            if(mouseX > (startX+threshold)) {
                gesture = "right"
                gestureStarted = true;
            }
            else if(mouseX < (startX+threshold)) {
                gesture = "left"
                gestureStarted = true;
            }
            // Makes codepad follow the swipe
            if(codePad.inView) {
                if(gesture == "right") {
                    swipeDistance = mouseX - startX
                    codePad.x = swipeDistance
                }
                if(gesture == "left") {
                    swipeDistance = startX - mouseX
                    codePad.x = -swipeDistance
                }
            }else {
                if(gesture == "right") {
                    swipeDistance = mouseX - startX
                    codePad.x = swipeDistance - parent.width
                }
                else if(gesture == "left") {
                    swipeDistance = startX - mouseX
                    codePad.x = parent.width - swipeDistance
                }

            }

        }
        // Animation to snap codepad into view or out of view
        onReleased: {
            displayOffTimer.restart()
            if(codePad.inView) {
                if(gesture == "right") {
                    if(swipeDistance > threshold) {
                        startCodePadAnimation(parent.width)
                        codePad.inView = false
                    }else {
                        startCodePadAnimation(0)
                        codePad.inView = true
                    }
                }else if(gesture == "left") {
                    if(swipeDistance > threshold) {
                        startCodePadAnimation(-parent.width)
                        codePad.inView = false
                    }else {
                        startCodePadAnimation(0)
                        codePad.inView = true
                    }
                }
            }else {
                if(swipeDistance > threshold) {
                    startCodePadAnimation(0)
                    codePad.inView = true
                }else {
                    if(gesture == "right") {
                        startCodePadAnimation(-parent.width)
                        codePad.inView = false
                    }
                    else {
                        startCodePadAnimation(parent.width)
                        codePad.inView = false
                    }
                }
            }

            gestureStarted = false
        }
        function startCodePadAnimation(value) {
            snapCodePadAnimation.valueTo = value
            snapCodePadAnimation.start()
        }

    }
    SequentialAnimation {
        id: snapCodePadAnimation

        property alias valueTo: codePadAnimation.to

        NumberAnimation {
            id: codePadAnimation
            target: codePad
            property: "x"
            duration: 200
            easing.type: Easing.OutQuint
        }
    }
    SequentialAnimation {
        id: unlockAnimation
        property alias valueTo: unlockNumAnimation.to
        property alias setProperty: unlockNumAnimation.property


        NumberAnimation {
            id: unlockNumAnimation
            target: lockScreen
            property: "y"
            to: -height
            duration: 250
            easing.type: Easing.OutQuint
        }
        onStopped: {
            setLockScreen(false)
        }
    }

    Connections {
        target:Lipstick.compositor
        onDisplayOff: {
            displayOn = false
            displayOffTimer.stop()
            codePad.x = -parent.width
            codePad.inView = false
        }
        onDisplayOn:{
            displayOn = true
            displayOffTimer.stop()
        }
    }

    Connections {
        target: LipstickSettings
        onLockscreenVisibleChanged: {
            if (lockscreenVisible() && displayOn) {
                displayOffTimer.restart()
            }
        }
    }
    Timer {
        id:displayOffTimer
        interval: 7000
        onRunningChanged: {
            if(running && !displayOn) {
                stop()
            }
        }
        onTriggered: {
            if(displayOn && lockscreenVisible() && !Lipstick.compositor.gestureOnGoing && !codepad.visible) {
                setLockScreen(true)
                Lipstick.compositor.setDisplayOff()
            }
        }
    }
    DeviceLockUI {
        id: codePad
        property bool inView: false
        property bool gestureStarted: mouseArea.gestureStarted

        x: width * 2
        visible: DeviceLock.state == DeviceLock.Locked && lockscreenVisible()
        width: lockScreen.width
        height: lockScreen.height / 2
        opacity: (1-Math.abs((1 - (-1)) * (x - (-parent.width)) / (parent.width - (-parent.width)) + (-1)))

        authenticationInput: DeviceLockAuthenticationInput {

            readonly property bool unlocking: registered
                        && DeviceLock.state >= DeviceLock.Locked && DeviceLock.state < DeviceLock.Undefined

            registered: lockscreenVisible()
            active: lockscreenVisible()

            onUnlockingChanged: {
                if (unlocking) {
                    DeviceLock.unlock()
                } else {
                    DeviceLock.cancel()
                }
            }
            onAuthenticationEnded: {
                if(confirmed) {
                    unlockAnimationHelper(mouseArea.gesture)
                }else {

                }

            }
            function unlockAnimationHelper(gesture) {
                if(gesture == "left") {
                    unlockAnimation.setProperty = "x"
                    unlockAnimation.valueTo = -width
                    unlockAnimation.start()
                }
                if(gesture == "right") {
                    unlockAnimation.setProperty = "x"
                    unlockAnimation.valueTo = width
                    unlockAnimation.start()
                }
            }
        }

        anchors {
            verticalCenter: lockScreen.verticalCenter
        }
        onGestureStartedChanged: {
            if(gestureStarted) {
                mouseArea.z = 2
            }else {
                mouseArea.z = 0
            }
        }
    }
    ListView {
        id: notificationColumn
        opacity: codePad.visible ? 1 - codePad.opacity : 1
        anchors{
            top: clock.bottom
            topMargin: Theme.itemSpacingHuge
            bottom:parent.bottom
            bottomMargin: Theme.itemSpacingHuge
            left:parent.left
            leftMargin: Theme.itemSpacingLarge
            right:parent.right
            rightMargin: Theme.itemSpacingLarge
        }
        interactive:DeviceLock.state !== DeviceLock.Locked
        spacing: Theme.itemSpacingExtraSmall

        model: NotificationListModel {
            id: notifmodel
        }
        clip:true
        delegate: NotificationItem {
            height: Theme.itemHeightLarge
            enabled:DeviceLock.state !== DeviceLock.Locked
            scale: notificationColumn.opacity
            transformOrigin: Item.Left
            iconSize: Theme.itemHeightMedium
            appName.font.pixelSize: Theme.fontSizeSmall
            appName.visible: DeviceLock.state !== DeviceLock.Locked
            appName.anchors.verticalCenter: labelColumn.verticalCenter
            appBody.font.pixelSize: Theme.fontSizeTiny
            appBody.visible: false
            appTimestamp.visible: false
            appSummary.visible: false
            pressBg.visible: DeviceLock.state !== DeviceLock.Locked
            pressBg.opacity: 0.3
        }
    }
}
