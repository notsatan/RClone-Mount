# Will simply login to the Google Drive account, fetch a list of all the drives that
# the account can view, and dump the data into a text file.

import pickle
from os import path
from typing import Dict, List

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import Resource, build

# Should be the name of the file that contains the token.
PICKLE_FILE: str = 'token.pickle'
# Should be the name of the JSON file containing credentails to use Google Drive API.
CREDENTIALS: str = 'credentials.json'


# If modifying these scopes, delete the `token.pickle` file if it exists.
SCOPES: List[str] = ['https://www.googleapis.com/auth/drive']

# A list containing the paths of the file(s) where the final output is to be written.
# Full paths are preferred if the file is to be saved outside of the root project
# directory. In order to maintain consistency, the default value should (first element)
# should not be changed, instead, if required, new paths can always be added.
#
# NOTE:
#   All the files whose paths are specified in `OUTPUT_FILES` will be created at the given path
#   if they do not exist. However, if any of those files already exists, it will be overwritten
#   and the previous data will be lost irrecoverably.
OUTPUT_FILES: List[str] = ['output.txt']


def getToken() -> Credentials:
    """
        Returns the credentials from the token file (if a token file is present and the credentials
        in it are valid), or asks the user to sign-in to a Google account that will then be used to
        generate the credentials

        Returns
        --------
        The token in the form of credentials.
    """

    creds: Credentials = None
    if path.exists(PICKLE_FILE):
        with open(PICKLE_FILE, 'rb') as token:
            # If a token file exists, reading credentials from it.
            creds = pickle.load(token)

    if not creds or not creds.valid:
        # If the pickle file does not exist, or if the credentials inside it are invalid,
        # generating new credentials or trying to refresh the previous one.
        if creds and creds.expired and creds.refresh_token:
            # If the creds are present but expired, then requesting new credentials.
            creds.refresh(Request())
        else:
            # If there are no valid creds inside the file, asking the user to log in again.
            flow = InstalledAppFlow.from_client_secrets_file(
                CREDENTIALS,
                SCOPES
            )

            creds = flow.run_local_server(port=0)

            # Once the creds are generated, saving them in the token file for the next run.
            with open(PICKLE_FILE, 'wb') as token:
                pickle.dump(creds, token)

    return creds


def buildService(credentials: Credentials) -> Resource:
    """
        Will be used to build drive service that is required to interact with Drive API.

        Returns
        --------
        An instance of drive service that will be used to interact with Drive API.
    """

    # Set `cache_discovery` to true only if the discovery doc is required.
    service = build(serviceName='drive',
                    version='v3',
                    credentials=credentials,
                    cache_discovery=False)

    return service


if __name__ == '__main__':
    print('Running\'')

    # Getting login credentials, and using them to generate drive service.
    creds: Credentials = getToken()
    drive_service: Resource = buildService(credentials=creds)

    # Fetching a list of all the drives that are linked to the Google Account.
    drives: List[Dict] = []
    token: str = ''
    while token is not None:
        res = drive_service.drives().list(
            pageSize=20,
            pageToken=token
        ).execute()

        token = res.get('nextPageToken', None)

        # Appending the list of new accounts generated to the end of the existing list.
        drives[-1:-1] = res.get('drives', [])

    # Opening the file and writing these accounts to the file.
    for file in OUTPUT_FILES:
        with open(file, 'wt', encoding='utf-8') as open_file:
            for drive in drives:
                # Writing data in the format:
                # [drive-name]
                # [drive-id]
                open_file.write(drive.get('name', 'nameless-drive') + '\n')
                open_file.write(drive.get('id', '') + '\n')

    # Printing the number of accounts found.
    print(f'Accounts Found: {len(drives)}')
