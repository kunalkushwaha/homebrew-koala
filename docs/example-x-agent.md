# Example: an X agent

[User guide](README.md) > Example: an X agent

This example runs a normal browser, Chromium, in a Koala VM. You sign in to
X in it through a live view on your Mac. A small agent in the same VM then
reads your timeline and searches, and asks a model which posts are worth a
reply and what to say. By default it only **drafts**. You read the drafts,
and approve what goes out. The agent then types and posts exactly that, at
a person's pace.

The code is in the `examples/x-agent` folder of Koala's Homebrew tap,
which Homebrew keeps on your Mac. Copy it to a folder of your own:

```sh
cp -R "$(brew --repository kunalkushwaha/koala)/examples/x-agent" ~/x-agent
```

> **X's rules.** X's terms restrict automating its website, and X can limit
> or suspend accounts it finds automated. Use a separate account, not your
> main one. X's official API is the sanctioned way to automate. The agent
> doesn't hide that it is automated: its pace and waits are what a person
> does, and what X's pages need.

Tested on 2026-10-14 and 15 with Koala 0.1.0-preview.7's code:
- **On X itself:** a test account, with Ollama's `gemma4:12b` on the Mac. It
  made one approved post and two approved replies.
- **By a test harness,** against a stand-in for X.

## What you need

- **Koala 0.1.0-preview.7 or later.** It has two fixes made for this
  example:
  - stopping a VM now lets its programs finish, so the browser keeps your
    sign-in;
  - a browser's network traffic no longer starves the VM of connections.
- **The `examples/x-agent` folder**, copied somewhere outside Desktop,
  Documents and Downloads. macOS protects those folders, and the VM reads
  the folder.
- **A model**, either:
  - **Ollama on your Mac**, the default, with a model pulled, for example
    `ollama pull gemma4:12b`;
  - **or an OpenAI-compatible provider through the [broker](broker.md),**
    with its key kept on your Mac.
- **About 8 GiB of free disk** (the VM's 6 GiB disk and a 2 GiB volume)
  and 4 GiB of memory, beyond what Koala keeps in reserve.

## Start the VM

With Ollama:

```sh
cd x-agent
./x-agent.sh up
```

With a provider through the broker: create the policy once, then start.
The policy asks for the key, which stays on your Mac:

```sh
koala policy create ai --template openai --model gpt-4.1-mini
./x-agent.sh up --broker ai
```

`up` does three things:
- creates the volume `x-agent-profile`, which keeps your sign-in and the
  agent's records;
- creates and starts the VM `x-agent`, from `debian:trixie-slim`;
- waits for Chromium.

The first start installs Chromium and fonts, which takes about a minute.
Later starts take seconds.

The VM can reach:
- **the internet,** for browsing;
- **your model:** only port 11434 on your Mac (Ollama), or the broker's
  policy.

The live view is published on your Mac's `127.0.0.1` only, with a password.

## Sign in through the live view

1. Open the address `up` printed:
   `http://127.0.0.1:6080/vnc.html?autoconnect=1&resize=scale`.
2. Enter the password that `./x-agent.sh password` shows.
3. In the VM's Chromium, go to `x.com` and sign in as you would anywhere.
   That includes any code or "confirm it's you" step. To X it is a new
   Linux computer.

**Tips:**
- Switch your Mac's keyboard to English input first.
- To paste, use noVNC's side panel: open its **Clipboard** box, paste your
  text there, then press Ctrl+V in the VM.

Your sign-in is kept on the volume. It survives `koala stop` and `start`,
and removing and recreating the VM.

## Check what the agent reads

```sh
./x-agent.sh check
```

It reads your timeline once, as the agent will. It prints your handle,
then each post's ID, author, time and the start of its text. Compare them
with what you see in the live view. A post with no time is an ad, which the
agent never replies to.

## Settings

Copy `settings/dry-run.json`, and set `me` to your handle, without the `@`.
`config` refuses the file until you do.

| Setting | What it does |
| --- | --- |
| `persona` | Who the model writes as, and what it replies to. The example is about microVMs and sandboxing. Change it to your topic. |
| `sources` | Where to read: `{"kind": "home"}`, `{"kind": "search", "query": "…"}`, `{"kind": "user", "handle": "…"}`. |
| `model` | The model's name, as your provider or Ollama knows it. |
| `replies` | `dryRun`, `perDay`, `perAuthorPerDay`, `minGapSeconds` (plus `jitterSeconds`), `maxLength`. |
| `compose` | Original posts: `topic`, `dryRun`, `perDay`, `minGapSeconds`, `maxLength`, and `context` (how many recent posts the model sees). |
| `readEverySeconds`, `scrolls` | How often it reads, and how far it scrolls. |

## Dry run: drafts only

```sh
./x-agent.sh config my-settings.json
./x-agent.sh logs
./x-agent.sh drafts
```

**The agent starts within 5 seconds of `config`.** Each round, it:
1. reads your sources;
2. asks the model about each new post: reply or not, and with what;
3. writes the drafts.

The model sees only each post's author and text, and your persona.

`logs` shows what it did, and why. For example, "skip …: the model chose
not to reply", or "no reply …: the daily limit (2) is reached".

`drafts` numbers each draft, and shows it beside the post it answers.

**Read the drafts before approving any.** A model can be confident and
wrong. In testing, one draft put a player in the wrong team.

## Approve what goes out

```sh
./x-agent.sh approve 2 5      # replies: drafts 2 and 5, as they are
./x-agent.sh approve post     # the latest post draft, as it is
```

The agent then posts only what you approved, within the guardrails, at
least `minGapSeconds` apart. For each one, it:
1. opens the post, and waits for the page to finish loading;
2. clicks that post's Reply;
3. types the text key by key;
4. closes X's hashtag and mention suggestions;
5. checks that the box holds exactly the approved text;
6. clicks Post;
7. waits for X to confirm.

To go back to drafting, install your settings again:
`./x-agent.sh config my-settings.json`.

**Without approvals,** a `replies` or `compose` section with `dryRun:
false` lets the model's drafts go out on their own, bounded only by the
guardrails. That hasn't been tested on X. Start with approvals.

## The guardrails

The agent's code enforces these; the model can't change them:
- daily limits for replies and posts, counted from the agent's records, so
  they hold across restarts;
- one reply per author a day;
- never twice to a post, and never the same post text twice;
- never your own posts, and never ads;
- a minimum gap between posts, with random variation;
- a length limit: a text that is too long is refused, not cut;
- no links in posts;
- nothing posts while `me` isn't set.

**Every attempt is recorded the moment Post is clicked.** If X doesn't
confirm it, the agent saves X's message and a screenshot, and never sends
it again: a missed reply is better than a double one.

**To stop the agent,** use `./x-agent.sh stop-agent`: it ends within a
round. `koala stop x-agent` also stops the agent first, then closes the
browser cleanly.

## Stop and remove

```sh
koala stop x-agent --wait          # keeps everything; koala start x-agent --wait resumes
./x-agent.sh down                  # removes the VM; the volume keeps your sign-in
./x-agent.sh down --forget         # also removes the volume: sign-in and records
```

## Where things are kept

On the `x-agent-profile` volume, inside the VM:
- **`/profile/chromium`:** the browser profile, with your session. Treat
  it like your password.
- **`/profile/vnc-password.txt`:** the live view's password.
- **`/profile/xagent/`:** the agent's settings and its records:
  - `agent.log`, `tweets.jsonl`, `drafts.jsonl`, `posted.jsonl`,
    `decisions.jsonl`, `unconfirmed.jsonl`;
  - screenshots of unconfirmed posts.

  Copy one out with `koala cp x-agent:/profile/xagent/agent.log .`.

One VM per X account: the browser's session is as valuable as the account.

## Troubleshooting

| What you see | What to do |
| --- | --- |
| `up` fails with `RESOURCE_ADMISSION_FAILED` | Your Mac is short of disk or memory beyond Koala's reserve. See [troubleshooting](troubleshooting.md#resources-and-storage). |
| `up` says Ollama isn't answering | Start Ollama, or use `--broker POLICY`. |
| The live view doesn't load | Use the address `up` printed, on this Mac. `--port N` chooses another port if 6080 is taken. |
| X says "Something went wrong… privacy related extensions" | Your Koala is too old for this example: see [What you need](#what-you-need). |
| `logs` shows `signed out: waiting for sign-in` | Sign in through the live view. The agent checks again each round. |
| `logs` shows `model: no answer … (URLError)` | The VM can't reach the model. While your Mac sleeps (a closed lid, for example), Koala suspends VMs' networks on purpose. Wake the Mac, check that Ollama runs, then `koala stop x-agent --wait` and `koala start x-agent --wait`. |
| `logs` shows "Post was clicked, but … not confirmed" | X didn't accept it, or didn't say. The agent won't retry it. Copy out the `unconfirmed-*.png` screenshot from `/profile/xagent/` to see X's message. |
| `check` or `config` says the agent is running, or `me` isn't set | Run `stop-agent` first; set `me` in your settings. |
