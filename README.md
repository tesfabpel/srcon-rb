# srcon-rb

A (very) simple Valve **RCON client** written in **Ruby**.

Usage:
```
ruby srcon.rb host port [-p -|password] [-- command]
```

If you pass `-p`, you can either specify the password as an argument, or via STDIN (if you pass `-`).

You can specify the command directly by passing `--` and the command thereafter.

You can also use it in your own server.  
In that case just replace the host with `localhost` or `127.0.0.1`.
