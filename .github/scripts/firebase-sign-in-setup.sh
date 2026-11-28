#!/usr/bin/env bash
# Registers the signing key with Firebase, turns on sign-in methods and refreshes google-services.json.
set -uo pipefail

summary() { echo "$*" >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"; }
grant_hint="Grant the role **Firebase Admin** to the service account in Google Cloud → IAM (project $FIREBASE_PROJECT), then run the build again."

key_file="$RUNNER_TEMP/sign-in-setup-sa.json"
printf '%s' "$FIREBASE_SERVICE_ACCOUNT" > "$key_file"
sa_email=$(jq -r .client_email "$key_file")
gcloud auth activate-service-account --key-file="$key_file" --quiet >/dev/null 2>&1
token=$(gcloud auth print-access-token 2>/dev/null)
rm -f "$key_file"
if [ -z "$token" ]; then
  echo "::warning::Sign-in setup skipped: could not get a token for the service account"
  exit 0
fi

api() { curl -sS -H "Authorization: Bearer $token" -H "Content-Type: application/json" "$@"; }
failed() { jq -e '.error' >/dev/null 2>&1 <<<"$1"; }
reason() { jq -r '.error.status + ": " + .error.message' <<<"$1"; }

summary "### Sign-in setup (service account \`$sa_email\`)"
summary ""

info=$(keytool -list -v -keystore "$KEYSTORE" -storepass "$STOREPASS" -alias "$ALIAS")
sha1=$(sed -n 's/.*SHA1: //p' <<<"$info" | tr -d ':' | tr 'A-F' 'a-f')
sha256=$(sed -n 's/.*SHA256: //p' <<<"$info" | tr -d ':' | tr 'A-F' 'a-f')
apps="https://firebase.googleapis.com/v1beta1/projects/$FIREBASE_PROJECT/androidApps/$APP_ID"

known=$(api "$apps/sha")
if failed "$known"; then
  summary "- Signing key: not registered ($(reason "$known")). $grant_hint"
else
  for pair in "SHA_1:$sha1" "SHA_256:$sha256"; do
    type=${pair%%:*}
    hash=${pair#*:}
    if jq -e --arg h "$hash" '.certificates // [] | map(.shaHash) | index($h)' >/dev/null <<<"$known"; then
      summary "- $type \`$hash\`: already registered"
    else
      added=$(api -X POST "$apps/sha" -d "{\"shaHash\":\"$hash\",\"certType\":\"$type\"}")
      if failed "$added"; then
        summary "- $type: not registered ($(reason "$added")). $grant_hint"
      else
        summary "- $type \`$hash\`: registered"
      fi
    fi
  done
fi

config="https://identitytoolkit.googleapis.com/admin/v2/projects/$FIREBASE_PROJECT/config"
mask="signIn.anonymous.enabled,signIn.email.enabled,signIn.email.passwordRequired"
body='{"signIn":{"anonymous":{"enabled":true},"email":{"enabled":true,"passwordRequired":false}}}'
updated=$(api -X PATCH "$config?updateMask=$mask" -d "$body")
if failed "$updated"; then
  case "$(jq -r .error.message <<<"$updated")" in
    *CONFIGURATION_NOT_FOUND*)
      summary "- Anonymous and Email link: Authentication is not started yet. Open Firebase console → Authentication → **Get started** once, then run the build again." ;;
    *)
      summary "- Anonymous and Email link: not turned on ($(reason "$updated")). $grant_hint" ;;
  esac
else
  summary "- Anonymous and Email link sign-in: on"
fi

google=$(api "https://identitytoolkit.googleapis.com/admin/v2/projects/$FIREBASE_PROJECT/defaultSupportedIdpConfigs/google.com")
if jq -e '.enabled == true' >/dev/null <<<"$google"; then
  summary "- Google sign-in: on"
else
  summary "- Google sign-in: off. It needs a web OAuth client that only the console creates: Firebase console → Authentication → Sign-in method → **Google** → Enable → Save, then run the build again."
fi

file=android/app/src/dev/google-services.json
fetched=$(api "$apps/config")
if failed "$fetched"; then
  summary "- google-services.json: not refreshed ($(reason "$fetched"))"
else
  jq -r .configFileContents <<<"$fetched" | base64 --decode | jq . > "$RUNNER_TEMP/google-services.json"
  if jq -e '.client[0].oauth_client | length > 0' >/dev/null "$RUNNER_TEMP/google-services.json"; then
    cp "$RUNNER_TEMP/google-services.json" "$file"
  fi
  if git diff --quiet -- "$file"; then
    summary "- google-services.json: up to date"
  else
    summary "- google-services.json: refreshed for this build (OAuth clients added). Commit the version printed in the log of this step."
    echo "----- google-services.json -----"
    cat "$file"
    echo "----- end -----"
  fi
fi
exit 0
