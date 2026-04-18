# Lab 04: Persistence and Defense Evasion on Windows

## Introduction

The purpose of this lab was to practice a Windows 10 host activity scenario involving both command execution through PowerShell and several persistence mechanisms. Unlike the previous labs, the focus here was placed not only on individual alerts, but also on linking execution, defense evasion, and persistence activity into one coherent chain of events.

As part of the exercise, the following actions were simulated:

- launching `powershell.exe` with the `-ExecutionPolicy Bypass` parameter
- executing the local script `lab4_payload.ps1`
- creating a `Run` entry in the user registry
- creating a file in the `Startup` folder
- creating a new Windows service named `Lab4Updater`

The lab used both built-in Wazuh rules and custom local rules added in `local_rules.xml`. This made it possible to compare default detection with custom tuning and verify which techniques are detected natively and which require extending the ruleset.

## Environment and Tools

The lab environment consisted of two virtual machines:

- Ubuntu Server with Wazuh Manager, Wazuh Dashboard, and Wazuh Indexer
- Windows 10 with the Wazuh agent and Sysmon

The following data sources and components were used:

- Wazuh Manager
- Wazuh Dashboard
- Wazuh Indexer
- Wazuh agent for Windows
- Sysmon
- `wazuh-alerts-*` and `wazuh-archives-*` indices

## Scenario Assumptions

The goal of the scenario was to simulate a simple chain of attacker or red team operator activity on a Windows workstation:

1. executing a PowerShell script while bypassing the standard execution policy
2. writing a persistence mechanism into the `Run` key
3. creating a startup file in the `Startup` folder
4. creating a new Windows service that starts automatically

The scenario made it possible to verify simultaneously:

- whether Wazuh correctly records activity in Sysmon telemetry
- which techniques are detected by built-in rules
- where custom tuning is needed
- what the correlation of several ATT&CK techniques looks like in a single exercise

## Custom Detection Rules

As part of the lab, custom local rules were prepared to extend Wazuh’s detection capabilities.

### 1. Rule `100210` – PowerShell with `ExecutionPolicy Bypass` or `EncodedCommand`

This rule was created to detect suspicious PowerShell execution with parameters commonly seen in defense evasion or execution scenarios.

```xml
<rule id="100210" level="12">
  <if_group>sysmon_event1</if_group>
  <field name="win.eventdata.image" type="pcre2">(?i)\\powershell\.exe$</field>
  <field name="win.eventdata.commandLine" type="pcre2">(?i)(-executionpolicy\s+bypass|-encodedcommand\b)</field>
  <description>Lab 4 - PowerShell with ExecutionPolicy Bypass or EncodedCommand</description>
  <mitre>
    <id>T1059.001</id>
  </mitre>
  <options>no_full_log</options>
</rule>
```

### 2. Rule `100213` – File creation in the `Startup` folder

This rule was created to detect the creation of a file in the user’s startup folder, which is a classic persistence mechanism.

```xml
<rule id="100213" level="11">
  <if_group>sysmon_event11</if_group>
  <field name="win.eventdata.targetFilename" type="pcre2">(?i)\\Start Menu\\Programs\\Startup\\</field>
  <description>Lab 4 - File created in Startup folder</description>
  <mitre>
    <id>T1547.001</id>
  </mitre>
  <options>no_full_log</options>
</rule>
```

## Scenario Analysis

### 1. PowerShell with `ExecutionPolicy Bypass`

The first stage of the scenario was launching:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "%USERPROFILE%\Desktop\Lab4-Test\lab4_payload.ps1"
```

The event details included, among other things:

- `image: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- `commandLine: powershell.exe -ExecutionPolicy Bypass -File ...`
- `parentImage: C:\Windows\System32\cmd.exe`

This means that the script was executed using a parameter that bypasses the standard execution policy, which from a SOC analyst’s perspective should be treated as suspicious behavior. Such parameters are often seen in simple defense evasion techniques and in malware activity launched from the command line.

In this scenario, two levels of detection were triggered:

- the built-in Wazuh alert `92029` with the description `Powershell executed script from suspicious location`
- the custom local rule `100210`, which directly detected the `ExecutionPolicy Bypass` pattern

This provided both general detection and detection tailored to the specific lab scenario.

- `screenshots/powershell_raport1.png`
- `screenshots/powershell_raport2.png`
- `screenshots/100210.png`

### 2. Persistence via the `Run` Registry Key

The next stage of the scenario was adding an entry to the user’s autorun key:

```cmd
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v Lab4Updater /t REG_SZ /d "powershell.exe -ExecutionPolicy Bypass -File C:\Users\user\Desktop\Lab4-Test\lab4_payload.ps1" /f
```

The logs showed Sysmon `eventID 13`, indicating a registry modification. In the `TargetObject` field, the following path was visible:

`HKU\...\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\Lab4Updater`

while the `Details` field contained the value launching PowerShell with the `ExecutionPolicy Bypass` parameter.

From a security analysis perspective, this is a classic example of persistence through `Registry Run Keys / Startup Folder`, consistent with technique `T1547.001`. In this case, the built-in Wazuh rule `92302` was triggered, with a description indicating that a registry entry executed at the next login had been modified using `reg.exe`.

In addition, earlier `reg.exe` activity was linked to suspicious registry value contents, showing that the same artifact can be analyzed from multiple perspectives: as a persistence modification and as suspicious entry content.

- `screenshots/run_key_persistence_raport1.png`
- `screenshots/run_key_persistence_raport2.png`

### 3. Persistence via the `Startup` Folder

Next, the following file was created:

`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\lab4_startup.bat`

The goal was to achieve command execution at the next user logon. In Sysmon telemetry, this was recorded as `eventID 11` – file creation. The `targetFilename` field showed the full path leading to the `Startup` directory.

Initially, the event was visible only as a more general alert related to the creation of a script file in the user directory. After correcting the local rule and retesting the scenario, a dedicated alert `100213` was generated with the description `Lab 4 - File created in Startup folder`.

This was an important part of the lab because it demonstrated the practical rule-tuning process: from a situation where the technique is visible only indirectly to the point where a clear alert tailored to a specific TTP is obtained.

- `screenshots/100213.png`

### 4. Persistence via a New Windows Service

The final stage of the scenario was creating a new Windows service named `Lab4Updater`, configured to start automatically at system boot. The `imagePath` field contained the following value:

`C:\Windows\System32\cmd.exe /c echo lab4_service>>C:\Users\Public\lab4_service.txt`

In practice, this was not a legitimate administrative service, but an artificially created persistence mechanism used only for lab purposes. From an incident analysis perspective, the following elements were important:

- `serviceName: Lab4Updater`
- `startType: autostart`
- `accountName: LocalSystem`
- `eventID: 7045`

The event was detected by the built-in Wazuh rule `61138` with the description `New Windows Service Created`. This is a valuable detection because the creation of new services by an interactive user is high-risk activity and is very often associated with persistence or attempts to gain elevated privileges.

During the analysis, activity related to the creation of the `Lab4Updater` service was also visible, which further confirmed the course of the scenario.

- `screenshots/lab4updater_raport1.png`
- `screenshots/lab4updater_raport2.png`

## Consolidated Alert View

The final analysis in the `wazuh-alerts-*` index showed that the environment recorded several techniques related to execution, defense evasion, and persistence at the same time. The consolidated view included the following alerts:

- `100210` – custom rule for PowerShell with `ExecutionPolicy Bypass`
- `100213` – custom rule for file creation in the `Startup` folder
- `92302` – built-in rule for persistence through the `Run Key`
- `61138` – built-in rule for new Windows service creation

This set clearly shows that even a simple lab scenario can generate several independent but logically related artifacts. From a SOC perspective, it is especially important to link these alerts into one incident narrative instead of analyzing each one in isolation.

- `screenshots/alerts.png`

## Summary of Results

During the lab, it was confirmed that the following were successfully detected:

- execution of PowerShell with the `ExecutionPolicy Bypass` parameter
- a persistence entry in the `Run` key
- creation of a file in the `Startup` folder
- creation of a new Windows service
- correct operation of the custom rules `100210` and `100213`
- cooperation between local detections and built-in Wazuh rules

The lab also showed that the rule-tuning process does not always succeed on the first attempt. Rule `100213` required an additional correction before a proper alert was generated. This is a realistic part of SIEM work: knowledge of the attack technique alone is not enough if the rule is not properly matched to the actual log structure.

## Module Conclusions

- PowerShell launched with `ExecutionPolicy Bypass` should be treated as elevated-risk activity, especially when it points to the execution of a local script from a user directory.
- Persistence through the `Run Key`, `Startup` folder, and a new Windows service can be effectively monitored in Wazuh, but the full quality of detection depends on proper rule tuning.
- Built-in Wazuh rules provide a good starting point, but custom local rules make it possible to detect exactly those patterns that matter from the perspective of a specific scenario.
- The greatest analytical value comes from combining several alerts into one activity timeline rather than analyzing each entry separately.
- The lab reflects a practical SOC workflow well: running the scenario, analyzing telemetry, refining rules, retesting, and verifying the final outcome.
