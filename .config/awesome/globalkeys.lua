-- #### Global key mappings ####

globalkeys = gears.table.join(
    awful.key({ modkey,           }, "l", function () awful.spawn(lock) end,
              {description="lock session", group="screen"}),
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),
    awful.key({ modkey,           }, "j", function () awful.client.focus.byidx(1) end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey,           }, "k", function () awful.client.focus.byidx(-1) end,
        {description = "focus previous by index", group = "client"}
    ),
    -- awful.key({            }, "Super_L", show_wibar,
    --      {description = "show the toolbar", group = "screen"}),
    -- awful.key({            }, "Super_R", show_wibar,
    --      {description = "show the toolbar", group = "screen"}),
    -- awful.key({ modkey     }, "Super_L", nil, hide_wibar,
    --      {description = "show the toolbar", group = "screen"}),
    -- awful.key({ modkey     }, "Super_R", nil, hide_wibar,
    --      {description = "show the toolbar", group = "screen"}),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "u", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "u", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    -- awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
    --           {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),
    awful.key({ modkey,            }, "k",      function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,            }, "h",      function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"    }, "h",      function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"    }, "k",      function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control"  }, "h",      function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control"  }, "k",      function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,            }, "space",  function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"    }, "space",  function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),

    -- Screenshots
    awful.key({                     }, "Print", function () awful.util.spawn_with_shell("maim -u ~/Pictures/screenshot_$(date +%F_%T).png")            end,
              {description = "screenshot fullscreen to file", group = "launcher"}),
    awful.key({            altmodkey }, "Print", function () awful.util.spawn_with_shell("maim -ust 9999999 ~/Pictures/screenshot_$(date +%F_%T).png")  end,
              {description = "screenshot window to file", group = "launcher"}),
    awful.key({             "Shift" }, "Print", function () awful.util.spawn_with_shell("maim -us ~/Pictures/screenshot_$(date +%F_%T).png")           end,
              {description = "screenshot selection to file", group = "launcher"}),
    awful.key({ "Control"           }, "Print", function () awful.util.spawn_with_shell("maim -u | xclip -selection clipboard -t image/png")           end,
              {description = "screenshot fullscreen to clipboard", group = "launcher"}),
    awful.key({ "Control", altmodkey }, "Print", function () awful.util.spawn_with_shell("maim -ust 9999999 | xclip -selection clipboard -t image/png") end,
              {description = "screenshot window to clipboard", group = "launcher"}),
    awful.key({ "Control" , "Shift" }, "Print", function () awful.util.spawn_with_shell("maim -us | xclip -selection clipboard -t image/png")          end,
              {description = "screenshot selection to clipboard", group = "launcher"}),
    awful.key({ modkey , "Shift" }, "s", function () awful.util.spawn_with_shell("maim -us | xclip -selection clipboard -t image/png")          end,
              {description = "screenshot selection to clipboard", group = "launcher"}),

    -- Application shortcuts
    awful.key({ modkey               }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ "Control", altmodkey }, "t",      function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey               }, "e", function () awful.spawn(file_browser)      end,
              {description = "open a file browser", group = "launcher"}),
    awful.key({ modkey, "Shift"      }, "r",      awesome.restart,
              {description = "reload awesome", group = "awesome"}),

    awful.key({ modkey, "Control"    }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                    c:emit_signal("request::activate", "key.unminimize", {raise = true})
                  end
              end,
              {description = "restore minimized", group = "client"}),

    -- Prompt
    awful.key({ modkey }, "r", function () awful.screen.focused().mypromptbox:run() end,
              {description = "run prompt", group = "launcher"}),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run {
                    prompt       = "Run Lua code: ",
                    textbox      = awful.screen.focused().mypromptbox.widget,
                    exe_callback = awful.util.eval,
                    history_path = awful.util.get_cache_dir() .. "/history_eval"
                  }
              end,
              {description = "lua execute prompt", group = "awesome"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #"..i, group = "tag"}),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"}),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end

-- Set keys
root.keys(globalkeys)
