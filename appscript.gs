const SHEET_NAME = "Users";
const SUMMARY_SHEET = "Summary";

// ── GET — dashboard reads data ────────────────────────────────
function doGet(e) {
  const action = (e.parameter && e.parameter.action) || "";

  if (action === "getUsers") {
    const ss    = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName(SHEET_NAME);
    if (!sheet) return json({ users: [] });

    const values = sheet.getDataRange().getValues();
    const users  = [];
    for (let i = 1; i < values.length; i++) {
      const row = values[i];
      if (!row[0]) continue;
      users.push({
        roblox_user_id:  String(row[0]),
        username:        String(row[1] || ""),
        game_name:       String(row[2] || ""),
        execution_count: Number(row[3]) || 0,
        first_seen:      String(row[4] || ""),
        last_seen:       String(row[5] || ""),
        hwid:            String(row[6] || ""),
        fingerprint:     String(row[7] || ""),
        ip_address:      String(row[8] || ""),
      });
    }
    return json({ users });
  }

  if (action === "getSummary") {
    const ss      = SpreadsheetApp.getActiveSpreadsheet();
    const summary = ss.getSheetByName(SUMMARY_SHEET);
    if (!summary) return json({ total_executions: 0, unique_users: 0, last_updated: "" });
    return json({
      total_executions: Number(summary.getRange("B1").getValue()) || 0,
      unique_users:     Number(summary.getRange("B2").getValue()) || 0,
      last_updated:     String(summary.getRange("B3").getValue()) || "",
    });
  }

  return json({ error: "unknown action" });
}

// ── POST — mainloader writes data ─────────────────────────────
function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const ss   = SpreadsheetApp.getActiveSpreadsheet();

    let sheet = ss.getSheetByName(SHEET_NAME);
    if (!sheet) {
      sheet = ss.insertSheet(SHEET_NAME);
      sheet.appendRow(["Roblox ID", "Username", "Game", "Executions", "First Seen", "Last Seen", "HWID", "Fingerprint", "IP"]);
      sheet.setFrozenRows(1);
      sheet.getRange("A1:I1").setFontWeight("bold");
    }

    const userId   = data.roblox_user_id;
    const username = data.username    || "";
    const gameName = data.game_name   || "";
    const hwid     = data.hwid        || "";
    const fp       = data.fingerprint || "";
    const ip       = data.ip_address  || "";
    const now      = formatTimestamp(new Date());

    const values = sheet.getDataRange().getValues();
    let foundRow = -1;
    for (let i = 1; i < values.length; i++) {
      if (String(values[i][0]) === String(userId) && values[i][2] === gameName) {
        foundRow = i + 1;
        break;
      }
    }

    if (foundRow > 0) {
      const currentCount = Number(sheet.getRange(foundRow, 4).getValue()) || 0;
      sheet.getRange(foundRow, 2).setValue(username);
      sheet.getRange(foundRow, 4).setValue(currentCount + 1);
      sheet.getRange(foundRow, 6).setValue(now);
      if (hwid) sheet.getRange(foundRow, 7).setValue(hwid);
      if (fp)   sheet.getRange(foundRow, 8).setValue(fp);
      if (ip)   sheet.getRange(foundRow, 9).setValue(ip);
    } else {
      sheet.appendRow([userId, username, gameName, 1, now, now, hwid, fp, ip]);
    }

    sheet.autoResizeColumns(1, 9);
    sheet.autoResizeRows(1, sheet.getLastRow());

    let summary = ss.getSheetByName(SUMMARY_SHEET);
    if (!summary) {
      summary = ss.insertSheet(SUMMARY_SHEET);
      summary.getRange("A1").setValue("Total Executions");
      summary.getRange("B1").setFormula('=SUM(Users!D:D)');
      summary.getRange("A2").setValue("Unique Users");
      summary.getRange("B2").setFormula('=COUNTA(UNIQUE(Users!A2:A))');
      summary.getRange("A3").setValue("Last Updated");
      summary.getRange("A1:A3").setFontWeight("bold");
      summary.getRange("B1:B2").setNumberFormat("0");
    }
    summary.getRange("B3").setValue(formatTimestamp(new Date()));
    summary.autoResizeColumns(1, 2);
    summary.autoResizeRows(1, 3);

    return json({ success: true });
  } catch (err) {
    return json({ success: false, error: err.toString() });
  }
}

// ── Helpers ───────────────────────────────────────────────────
function json(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function formatTimestamp(date) {
  const m  = date.getMonth() + 1;
  const d  = date.getDate();
  const y  = date.getFullYear();
  const hh = String(date.getHours()).padStart(2, "0");
  const mm = String(date.getMinutes()).padStart(2, "0");
  return `${m}/${d}/${y} ${hh}:${mm}`;
}

function testPost() {
  const fake = {
    postData: {
      contents: JSON.stringify({
        roblox_user_id: 123456789,
        username:       "TestUser",
        game_name:      "Pixel Blade",
        hwid:           "HW-abc123",
        fingerprint:    "FP-def456",
        ip_address:     "1.2.3.4",
      })
    }
  };
  Logger.log(doPost(fake).getContent());
}

function testGet() {
  const fake = { parameter: { action: "getSummary" } };
  Logger.log(doGet(fake).getContent());
}
