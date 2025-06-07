https://github.com/urob/zmk-config

Initialize if `.west` directory doesn't exist yet:
```bash
just init
```

Build board firmware locally:
```bash
just build all
# if it doesnt work because of some permission error, do the following
XDG_RUNTIME_DIR=/tmp just build all
```

Files are then located in `firmware/`

![](img/corne.svg)
