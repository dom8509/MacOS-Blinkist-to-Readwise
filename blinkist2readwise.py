import readwise_util as ru
import sys
import runcmd
import argparse
import json

parser = argparse.ArgumentParser()
# Required positional argument, for capturing the email address used to log in to the
# Blinkist account
parser.add_argument(
    "blinkist_email",
    help="specify the email address used to log in to your Blinkist account"
)
# Required positional argument, for capturing the password used to log in to the
# Blinkist account
parser.add_argument(
    "blinkist_password",
    help="specify the password used to log in to your Blinkist account"
)
# Optional argument, used to download all Blinkist highlights into a CSV file
parser.add_argument(
    "-d",
    "--download",
    help="download all Blinkist highlights into a CSV file",
    action="store_true"
)

# Optional argument, used to specify the token used to interact with the user's
# Readwise highlights
parser.add_argument(
    "-t",
    "--token-readwise",
    help="specify the token used to access your Readwise highlights"
)
args = parser.parse_args()
print(args)

BLINKIST_EMAIL = args.blinkist_email
BLINKIST_PASSWORD = args.blinkist_password
READWISE_TOKEN = args.token_readwise
# Download the CSV if the option is passed or if no Readwise token is passed
DOWNLOAD_CSV = args.download or (READWISE_TOKEN is None)

# First, we load the current user's Readwise highlights, if the token was provided.
# We will use this information to check if highlights found on the Blinkist
# page are already saved on Readwise, and thus to know if we need to load
# more ancient highlights or not
readwise_highlights = None
if READWISE_TOKEN is not None:
    print('Fetching current Readwise highlights...')
    readwise_highlights = ru.get_all_readwise_highlights(READWISE_TOKEN)
    if readwise_highlights is None:
        sys.exit('Script interrupted due to error.')
    with open('tmp/readwise_highlights.json', 'w') as file:
        json.dump(readwise_highlights, file, indent=2)


def get_highlight_object(fetched_object):
    # Function to prepare the highlight objects that will be uploaded to Readwise
    return {
        'text': fetched_object['highlight'],
        'title': 'Blink - ' + fetched_object['book_title'],
        'image_url': 'https://upload.wikimedia.org/wikipedia/en/c/ca/Blinkist_logo.png',
        'source_type': 'book',
        'author': 'Blinkist'
    }


def run_osascript(applescript, args, background=False):
    script_args = []
    for arg in args:
        if isinstance(arg, bool):
            script_args.append("true" if arg else "false")
        else:
            script_args.append(arg)
    cmd = ["osascript", applescript] + script_args

    return runcmd.run(cmd, background=background)


# Fetch the Readwise highlights
fetched_highlights = []
res = run_osascript(
    'bin/blikist_scrapper.scpt', ["tmp/readwise_highlights.json", DOWNLOAD_CSV])

if res.code == 0:
    with open("tmp/blinkist_highlights.json", 'r') as file:
        fetched_highlights = json.load(file)

        if len(fetched_highlights) > 0:
            print("Nothing to do -> all Readwise highlights are up to date.")
        elif READWISE_TOKEN is not None:
            # Prepare a new list of highlight objects from our previously fetched and sorted results
            highlight_objects = []
            fetched_highlights.reverse()  # reverse list to get oldest highlights first
            for highlight in fetched_highlights:
                highlight_objects.append(get_highlight_object(highlight))

            # Upload the highlights to Readwise
            api_response = ru.export_highlights_to_readwise(
                READWISE_TOKEN, highlight_objects)

            if api_response.status_code != 200:
                sys.exit('Script interrupted due to error.')
            else:
                print("Success: Blinkist highlights uploaded to Readwise!")

        # Save the highlights into a CSV if the user chose this option
        if DOWNLOAD_CSV:
            print('Saving Blinkist highlights to a CSV file...')
            with open('blinkist_highlights.csv', 'w') as f:
                f.writelines('Highlight,Title\n')
                for i in range(len(fetched_highlights)-1, 0, -1):
                    book = fetched_highlights[i]['book_title']
                    highlight = fetched_highlights[i]['highlight']
                    f.writelines('"' + highlight + '","' + book +
                                 '"' + ('\n' if i > 0 else ''))

            print("Success: Blinkist highlights extracted to a CSV file!")
else:
    print(res.out)
    print(res.err)