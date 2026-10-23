# Fork Revert Hunks

[English](#english) | [日本語](#日本語)

<a id="english"></a>

Custom commands for the [Fork](https://git-fork.com/) Git client that bring SourceTree's **"Reverse hunk"** to Fork.

They reverse-apply changes from an existing commit (including pushed commits) to your working tree. Nothing is committed or pushed — you review the result and commit it yourself.

## Commands

Select a commit in the history, then right-click a file in its file list:

| Command | What it does |
|---|---|
| **Revert File Changes** | Reverse-applies all of this file's changes in that commit |
| **Revert Hunks…** | Lists the file's hunks and reverse-applies only the ones you pick by number (e.g. `1 3`, `1,3`, `all`; leave empty to cancel) |

## Requirements

- [Fork](https://git-fork.com/) for macOS or Windows (launch it at least once before installing)
- Git (on Windows, Git for Windows, which provides `bash`)

## Install

1. Download or clone this repository.
2. Run the installer:
   - **Windows:** double-click `install-windows.bat`
   - **macOS:** run `bash install-mac.command` in Terminal
     (to double-click it in Finder instead, right-click → **Open** the first time)
3. Restart Fork.

Running the installer again updates the commands. Your other custom commands are left untouched.

## Uninstall

- **Windows:** `install-windows.bat -Uninstall`
- **macOS:** `bash install-mac.command --uninstall`

## Where things go

| | Path |
|---|---|
| Script | `~/fork-scripts/revert-hunks.sh` |
| Fork settings (Windows) | `%LOCALAPPDATA%\Fork\custom-commands.json` |
| Fork settings (macOS) | `~/Library/Application Support/com.DanPristupov.Fork/custom-commands.json` |

Before changing the settings file, the installer backs it up as `custom-commands.json.bak-<timestamp>`.

## Notes

- Hunks are split using Git's default of 3 context lines. If you changed the number of context lines in Fork's diff view, the hunk boundaries shown by Fork may differ.
- If a hunk no longer applies cleanly, a 3-way merge is tried and the result is staged. If that causes conflicts, resolve them in Fork.
- On macOS, **Revert Hunks…** opens a Terminal window. The first time, macOS asks whether Fork may control Terminal — allow it.
- For merge commits, changes are taken relative to the first parent (same as Fork's diff view).

## License

[MIT](LICENSE)

---

<a id="日本語"></a>

# Fork Revert Hunks（日本語）

SourceTree の「この変更 (Hunk) を取り消す」と同等の操作を、Git クライアント [Fork](https://git-fork.com/) に追加するカスタムコマンドです。

コミット済み（Push済みを含む）の変更を、作業ツリーに逆適用します。コミットや Push は行わないので、結果を確認してからご自身でコミットしてください。

## 追加されるコマンド

履歴でコミットを選び、ファイル一覧のファイルを右クリックすると使えます。

| コマンド | 動作 |
|---|---|
| **Revert File Changes** | そのコミットでの、そのファイルの変更をすべて逆適用 |
| **Revert Hunks…** | Hunk 一覧を表示し、番号で選んだ Hunk だけを逆適用（例: `1 3` / `1,3` / `all`。空でキャンセル） |

## 必要なもの

- [Fork](https://git-fork.com/)（macOS または Windows。インストール前に一度起動しておいてください）
- Git（Windows では `bash` を含む Git for Windows）

## インストール

1. このリポジトリをダウンロードまたは clone します。
2. インストーラを実行します。
   - **Windows:** `install-windows.bat` をダブルクリック
   - **macOS:** ターミナルで `bash install-mac.command` を実行
     （Finder でダブルクリックする場合は、初回は右クリック →「開く」）
3. Fork を再起動します。

再実行すると上書き更新されます。既存の他のカスタムコマンドはそのまま残ります。

## アンインストール

- **Windows:** `install-windows.bat -Uninstall`
- **macOS:** `bash install-mac.command --uninstall`

## インストール先

| | パス |
|---|---|
| スクリプト | `~/fork-scripts/revert-hunks.sh` |
| Fork の設定（Windows） | `%LOCALAPPDATA%\Fork\custom-commands.json` |
| Fork の設定（macOS） | `~/Library/Application Support/com.DanPristupov.Fork/custom-commands.json` |

設定ファイルは書き換え前に `custom-commands.json.bak-<日時>` としてバックアップされます。

## 注意

- Hunk の区切りは git 標準（前後3行の文脈）です。Fork の差分表示の文脈行数を変えている場合は、Fork 上の表示と区切りがずれることがあります。
- そのまま当たらない場合は 3-way マージで適用し、結果はステージ済みに入ります。コンフリクトした場合は Fork で解決してください。
- macOS では **Revert Hunks…** がターミナルを開きます。初回は Fork から Terminal の操作許可を求められるので、許可してください。
- マージコミットの場合は、1つ目の親との差分を対象にします（Fork の差分表示と同じ）。

## ライセンス

[MIT](LICENSE)
