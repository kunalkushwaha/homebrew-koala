# Hermes

A Koala example. It runs the [Hermes agent](https://github.com/NousResearch/hermes-agent)'s
gateway in a VM:
- with no internet access;
- with your model provider's API key on your Mac, reached through Koala's
  broker;
- with Hermes's data on a volume;
- with its API on `127.0.0.1:8642`.

The full walk-through is the user guide's
[Example: run the Hermes agent](../../docs/example-hermes.md).

## Run it

```sh
koala create hermes --template hermes            # asks for your API key, then sets it all up
curl -s http://127.0.0.1:8642/health             # the gateway
koala exec hermes -- hermes chat -q "Hello"      # ask Hermes
```

- `--set model=M` picks another model.
- `--set origin=URL` picks another OpenAI-compatible provider.
- `--set port=N` picks another port.
- `koala template inspect hermes` lists the parameters, and what the
  template makes.

`koala` has `template.json` built in as the `hermes` template. To change it,
edit your copy and use the file instead:

```sh
koala create hermes --template ./template.json
```

To remove it all:

```sh
koala stop hermes --wait && koala rm hermes
koala volume rm hermes-data && koala policy rm hermes-openai && koala credential rm hermes-openai
```

You need Koala 0.1.0-preview.9 or later, and an
OpenAI-compatible API key.

## Files

| File | What it is |
| --- | --- |
| `template.json` | The template: the VM, its broker policy and volume, and the setup it runs in Hermes. |
