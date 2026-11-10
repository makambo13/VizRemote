// Local Jenkins pipeline for VizRemote (macOS + iOS).
//
// Runs natively on this Mac's Jenkins agent — NOT in Docker. Xcode, codesign, and the
// login keychain aren't reachable from inside a standard container, so a containerized
// agent can't actually build or sign these targets. Jenkins itself is installed via
// `brew install jenkins-lts` and runs as a normal macOS process/launchd service.
//
// Stages that archive/sign/upload (mac_release, ios_beta, ios_release) require a paid
// Apple Developer Program membership — see fastlane/Fastfile's
// `ensure_developer_account_configured` check, which fails those lanes with a clear
// message rather than a cryptic Apple auth error until that's set up.

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        booleanParam(name: 'RELEASE_MAC', defaultValue: false, description: 'Archive + upload the macOS app to the Mac App Store (requires a paid Developer account)')
        booleanParam(name: 'RELEASE_IOS_BETA', defaultValue: false, description: 'Archive + upload the iOS app to TestFlight (requires a paid Developer account)')
        booleanParam(name: 'RELEASE_IOS', defaultValue: false, description: 'Archive + upload the iOS app to the App Store (requires a paid Developer account)')
    }

    stages {
        stage('Test') {
            steps {
                sh 'fastlane ci'
            }
        }

        stage('Release: macOS') {
            when { expression { return params.RELEASE_MAC } }
            steps {
                sh 'fastlane mac_release'
            }
        }

        stage('Release: iOS TestFlight') {
            when { expression { return params.RELEASE_IOS_BETA } }
            steps {
                sh 'fastlane ios_beta'
            }
        }

        stage('Release: iOS App Store') {
            when { expression { return params.RELEASE_IOS } }
            steps {
                sh 'fastlane ios_release'
            }
        }
    }

    post {
        always {
            // Test results/coverage bundles land under fastlane's default output dir.
            archiveArtifacts artifacts: 'fastlane/test_output/**', allowEmptyArchive: true
        }
    }
}
