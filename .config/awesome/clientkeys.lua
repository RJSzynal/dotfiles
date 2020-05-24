-- #### Client key mappings ####

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey, "Shift"   }, "q",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "Down",
        function (c)
            if c.maximized then
                c.maximized = not c.maximized
            else
                -- The client currently has the input focus, so it cannot be
                -- minimized, since minimized clients can't have the focus.
                c.minimized = true
            end
        end ,
        {description = "unmaximise/minimise", group = "client"}),
    awful.key({ modkey,           }, "Up",
        function (c)
            if not c.maximized then
                c.maximized = not c.maximized
                c:raise()
            end
        end ,
        {description = "maximise", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c)
            c.maximized_vertical = not c.maximized_vertical
            c:raise()
        end ,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c:raise()
        end ,
        {description = "(un)maximize horizontally", group = "client"}),

    -- Alt-Tab: cycle through clients on the same screen.
    -- This must be a clientkeys mapping to have source_c available in the callback.
    cyclefocus.key({ altmodkey           }, "Tab", {
        cycle_filters = { cyclefocus.filters.same_screen, cyclefocus.filters.common_tag },
    }),
    cyclefocus.key({ altmodkey, "Shift"  }, "Tab", {
        cycle_filters = { cyclefocus.filters.same_screen, cyclefocus.filters.common_tag },
    }),
    -- Alt-`: cycle through clients with the same class name.
    cyclefocus.key({ altmodkey           }, backtickkey, {
        cycle_filters = { cyclefocus.filters.same_screen, cyclefocus.filters.common_tag, cyclefocus.filters.same_class },
        keys = { "`", "¬" },  -- the keys to be handled, wouldn't be required if the keycode was available in keygrabber.
    }),
    cyclefocus.key({ altmodkey, "Shift", }, backtickkey, {
        cycle_filters = { cyclefocus.filters.same_screen, cyclefocus.filters.common_tag, cyclefocus.filters.same_class },
        keys = { "`", "¬" },
    })
)
