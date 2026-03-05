#!/bin/bash

# Vercel Ignored Build Step
# https://vercel.com/docs/projects/overview#ignored-build-step
#
# Exit 1 = proceed with build
# Exit 0 = skip build
#
# Only build when files in web/ or agentassist-build/ change.
# Changes to ios/ or other top-level files won't trigger a redeploy.

git diff --quiet HEAD^ HEAD -- . ../agentassist-build/
