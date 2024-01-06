/** @format */

ObjC.import("Cocoa");
ObjC.import("stdlib");

var url = "https://www.blinkist.com/en/nc/login?last_page_before_login=%2Fen%2Fnc%2Fhighlights";
var email = "dominik.stamm@me.com";
var password = "eWeXBR.D@MVG6yt@";
var siteLoadDelay = 5;
var contentLoadDelay = 1;

function openSite(url) {
  let Safari = Application("Safari");

  Safari.activate();
  window = Safari.windows[0];

  let tab = Safari.Tab({ url: url });
  window.tabs.push(tab);
  window.currentTab = tab;

  delay(siteLoadDelay);

  return Safari;
}

function loginBlinkist(Safari, email, password) {
  console.log("Logging in to Blinkist ...");
  if (Safari.doJavaScript("document.getElementsByName('login[email]').length", { in: tab })) {
    Safari.doJavaScript(
      "document.getElementsByName('login[email]')[0].value = '" +
        email +
        "'; document.getElementsByName('login[password]')[0].value = '" +
        password +
        "'; document.getElementsByName('commit')[0].click()",
      { in: tab }
    );

    delay(siteLoadDelay);
  } else {
    console.log("Already logged in.");
  }

  return true;
}

function strip(str) {
  return str.replace(/^\s+|\s+$/g, "");
}

function shouldKeepLoading(readwise_highlights, download_csv, blinkist_highlights) {
  if (download_csv) {
    return true;
  }

  let already_saved = false;
  let oldest_blinkist_highlight = blinkist_highlights[blinkist_highlights.length - 1]["highlight"];
  
  for (highlight of readwise_highlights) {
    if (strip(highlight.text) === strip(oldest_blinkist_highlight)) {
      already_saved = true;
      break;
    }
  }
  return !already_saved;
}

function writeStringToFile(string, filePath) {
  var str = $.NSString.alloc.initWithUTF8String(string);
  str.writeToFileAtomicallyEncodingError(filePath, true, $.NSUTF8StringEncoding, null);
}

function writeJSONToFile(json_data, path) {
  // Konvertieren Sie das JSON-Objekt in einen String
  var json_string = JSON.stringify(json_data, null, 2);
  writeStringToFile(json_string, path);
}

function readFile(path) {
  var file_content = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
  return file_content.js;
}

function readJSONFile(path) {
  var file_content = readFile(path);
  return JSON.parse(file_content);
}

function convertHtmlToJson(html_string) {
  cwd = $.getenv("PWD");

  writeStringToFile(html_string, "tmp/page_source.html");

  command = cwd + "/venv/bin/python";
  script = cwd + "/src/python/convert_Html_to_json.py";

  app = Application.currentApplication();
  app.includeStandardAdditions = true;
  result = app.doShellScript(command + " " + script);

  blinkist_highlights = readFile("tmp/page_source_converted.json");

  return JSON.parse(blinkist_highlights);
}

function removeKnownHighlights(readwise_highlights, download_csv, blinkist_highlights) {
  if (download_csv) {
    return true;
  }

  let highlights_to_remove = 0;
  let all_highlights_new = false;
  
  while (blinkist_highlights.length > 0 && !all_highlights_new) {
    let oldest_blinkist_highlight = blinkist_highlights[blinkist_highlights.length - 1]["highlight"];
    let highlights_to_remove_found = false;

    for (highlight of readwise_highlights) {
      if (strip(highlight.text) === strip(oldest_blinkist_highlight)) {
        highlights_to_remove += 1;

        blinkist_highlights.pop();

        highlights_to_remove_found = true;
        break;
      }
    }

    if (!highlights_to_remove_found) {
      all_highlights_new = true;
    }
  }

  console.log("Removed " + highlights_to_remove + " already synced highlights from the list.")

  return blinkist_highlights;
}

function run(argv) {
  console.log("Executing JXA Script ...");

  var download_csv = argv[1].toLowerCase() === "true";

  var readwise_highlights = readJSONFile(argv[0]);
  console.log("Loaded " + readwise_highlights.length + " highlights from Readwise.");

  // open url in new tab
  Safari = openSite(url);
  tab = Safari.windows[0].currentTab();

  // login to blinkist
  var login_successfull = loginBlinkist(Safari, email, password);

  if (login_successfull) {
    console.log("Loading Blinklist highlights ...");
    // go to page with highlights sorted by date
    Safari.doJavaScript(`document.querySelectorAll("a[data-order-by='date']")[0].click()`, { in: tab });
    delay(siteLoadDelay);

    blinkist_highlights = convertHtmlToJson(Safari.doJavaScript("document.documentElement.outerHTML", { in: tab }));
    console.log("Found " + blinkist_highlights.length + " Blinkist highlights.");

    keep_loading = shouldKeepLoading(readwise_highlights, download_csv, blinkist_highlights);
    while (keep_loading) {
      if (
        Safari.doJavaScript(
          `document.getElementsByClassName('js-text-markers-v2-load-more').length && document.getElementsByClassName('js-text-markers-v2-load-more')[0].style.display == 'block'`,
          { in: tab }
        )
      ) {
        console.log("Loading more highlights ...");
        Safari.doJavaScript(`document.getElementsByClassName('js-text-markers-v2-load-more')[0].click()`, { in: tab });

        delay(contentLoadDelay);

        blinkist_highlights = convertHtmlToJson(Safari.doJavaScript("document.documentElement.outerHTML", { in: tab }));
        console.log("Found " + blinkist_highlights.length + " Blinkist highlights.");

        keep_loading = shouldKeepLoading(readwise_highlights, download_csv, blinkist_highlights);
      } else {
        keep_loading = false;
      }
    }
  }

  blinkist_highlights = removeKnownHighlights(readwise_highlights, download_csv, blinkist_highlights);
  console.log("Dumping Blinklist highlights to JSON file ...");
  writeJSONToFile(blinkist_highlights, "tmp/blinkist_highlights.json");

  tab.close();
}
