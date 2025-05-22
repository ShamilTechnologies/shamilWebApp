#!/bin/bash

echo "==================================="
echo "Deploying Firestore Indexes"
echo "==================================="

echo "Installing Firebase CLI if not already installed..."
npm install -g firebase-tools

echo "Logging in to Firebase (if not already logged in)..."
firebase login

echo "Deploying Firestore indexes..."
firebase deploy --only firestore:indexes

echo "==================================="
echo "Deployment completed!"
echo "===================================" 