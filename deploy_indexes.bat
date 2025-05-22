@echo off
echo ===================================
echo Deploying Firestore Indexes
echo ===================================

echo Installing Firebase CLI if not already installed...
call npm install -g firebase-tools

echo Logging in to Firebase (if not already logged in)...
call firebase login

echo Deploying Firestore indexes...
call firebase deploy --only firestore:indexes

echo ===================================
echo Deployment completed!
echo ===================================
pause 