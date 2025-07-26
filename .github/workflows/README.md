# CI/CD Setup for Nutsack

This repository uses GitHub Actions for continuous integration and deployment to TestFlight.

## Workflows

### CI (`ci.yml`)
- Runs on every push to main/master and on pull requests
- Builds the app for iOS Simulator
- Runs tests if available
- Uses Xcode 15.4 on macOS 14

### TestFlight Deployment (`testflight.yml`)
- Triggered by version tags (e.g., `v1.0.0`) or manual dispatch
- Builds the app for release
- Archives and exports IPA
- Uploads to TestFlight using App Store Connect API

## Required Secrets

Configure these secrets in your repository settings:

- `APP_STORE_CONNECT_API_KEY`: Base64 encoded .p8 key file
- `APP_STORE_CONNECT_API_KEY_ID`: Your API Key ID
- `APP_STORE_CONNECT_ISSUER_ID`: Your Issuer ID
- `DEVELOPMENT_TEAM`: Your Apple Developer Team ID (e.g., "456SHKPP26")

## Deployment Process

1. Create a version tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. The workflow will automatically:
   - Build the app
   - Create an IPA file
   - Upload to TestFlight

3. Or trigger manually from GitHub Actions tab

## Local Testing

To test the build process locally:
```bash
./build.sh
```

To deploy manually:
```bash
./deploy.sh
```