# Hsss

Hash-Safe Script Splinterer, a Lua Script and hash embedder into C source. 
Good for putting Redis Lua scripts in your C headers.
```
Usage: hsss [options] files
  --struct [redis_lua_script_t]     C struct name
  --scripts [redis_lua_scripts]     Scripts variable
  --hashes [redis_lua_hashes]       Hashes variable
  --names [redis_lua_script_names]  Script names variable
  --count [redis_lua_scripts_count] integer script count variable
  --no-count                        Omit script count variable
  --each-macro [REDIS_LUA_SCRIPTS_EACH] Iterator macro
  --no-each                         Omit the iterator macro
  --no-parse                        Skip using luac to check script syntax
  --prefix PREFIX                   Prefix default names with this
```

## Example

Let's say you have two scripts in directory `example/`:

`echo.lua`:
```lua
--echoes the first argument
redis.call('echo', ARGS[1])

```

`delete.lua`
```lua
--deletes first key
redis.call('del', KEYS[1])

```

running `hsss example/*.lua" outputs
```c
//don't edit this please, it was auto-generated

typedef struct {
  //deletes first key
  char *delete;

  //echoes the first argument
  char *echo;

} redis_lua_script_t;

static redis_lua_script_t redis_lua_hashes = {
  "c6929c34f10b0fe8eaba42cde275652f32904e03",
  "8f8f934c6049ab4d6337cfa53976893417b268bc"
};

static redis_lua_script_t redis_lua_script_names = {
  "delete",
  "echo",
};

static redis_lua_script_t redis_lua_scripts = {
  //delete
  "--deletes first key\n"
  "redis.call('del', KEYS[1])\n",

  //echo
  "--echoes the first argument\n"
  "redis.call('echo', ARGS[1])\n"
};

const int redis_lua_scripts_count=2;
#define REDIS_LUA_SCRIPTS_EACH(script_src, script_name, script_hash) \
for((script_src)=(char **)&redis_lua_scripts, (script_hash)=(char **)&redis_lua_hashes, (script_name)=(char **)&redis_lua_script_names; (script_src) < (char **)(&redis_lua_scripts + 1); (script_src)++, (script_hash)++, (script_name)++)
```

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

