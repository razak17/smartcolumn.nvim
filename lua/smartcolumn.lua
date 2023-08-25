local smartcolumn = {}

local config = {
   colorcolumn = "0",
   disabled_filetypes = { "help", "text", "markdown" },
   custom_colorcolumn = {},
   buffer_config = {},
   scope = "file",
}

local function exceed(buf, win, min_colorcolumn)
   local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, true) -- file scope
   if config.scope == "line" then
      lines = vim.api.nvim_buf_get_lines(
         buf,
         vim.fn.line(".", win) - 1,
         vim.fn.line(".", win),
         true
      )
   elseif config.scope == "window" then
      lines = vim.api.nvim_buf_get_lines(
         buf,
         vim.fn.line("w0", win) - 1,
         vim.fn.line("w$", win),
         true
      )
   end

   local max_column = 0
   for _, line in pairs(lines) do
      max_column = math.max(max_column, vim.fn.strdisplaywidth(line))
   end

   return not vim.tbl_contains(config.disabled_filetypes, vim.bo.ft)
      and max_column > min_colorcolumn
end

local function update()
   local buf_filetype = vim.api.nvim_buf_get_option(0, "filetype")
   local colorcolumns

   if type(config.custom_colorcolumn) == "function" then
      colorcolumns = config.custom_colorcolumn()
   else
      colorcolumns = config.custom_colorcolumn[buf_filetype]
         or config.colorcolumn
   end

   local current_buf = vim.api.nvim_get_current_buf()
   if config.buffer_config[current_buf] then
      colorcolumns = config.buffer_config[current_buf].colorcolumn
   end

   local min_colorcolumn
   local textwidth = vim.opt.textwidth:get()

   if type(colorcolumns) == "string" then
      if vim.startswith(colorcolumns, "+") then
         if textwidth ~= 0 then
            min_colorcolumn = textwidth
         end
      elseif vim.startswith(colorcolumns, "-") then
         if textwidth ~= 0 then
            min_colorcolumn = textwidth - tonumber(colorcolumns:sub(2))
         else
         end
      else
         min_colorcolumn = colorcolumns
      end
   else
      if type(colorcolumns) == "table" then
         for i, c in ipairs(colorcolumns) do
            if vim.startswith(c, "+") then
               if textwidth ~= 0 then
                  colorcolumns[i] = textwidth
               end
            elseif vim.startswith(c, "-") then
               if textwidth ~= 0 then
                  colorcolumns[i] = textwidth - tonumber(c:sub(2))
               end
            else
               colorcolumns[i] = tonumber(c)
            end
         end
         min_colorcolumn = colorcolumns[1]
         for _, colorcolumn in pairs(colorcolumns) do
            min_colorcolumn = math.min(min_colorcolumn, colorcolumn)
         end
      end
   end
   min_colorcolumn = tonumber(min_colorcolumn)

   if not min_colorcolumn then
      return
   end

   local wins = vim.api.nvim_list_wins()
   for _, win in pairs(wins) do
      local buf = vim.api.nvim_win_get_buf(win)
      if buf == current_buf then
         local current_state = exceed(buf, win, min_colorcolumn)
         if current_state ~= vim.b.prev_state then
            vim.b.prev_state = current_state
            if current_state then
               if type(colorcolumns) == "table" then
                  vim.wo[win].colorcolumn = table.concat(colorcolumns, ",")
               else
                  vim.wo[win].colorcolumn = colorcolumns
               end
            else
               vim.wo[win].colorcolumn = nil
            end
         end
      end
   end
end

function smartcolumn.setup(user_config)
   user_config = user_config or {}

   for option, value in pairs(user_config) do
      config[option] = value
   end

   vim.api.nvim_create_autocmd(
      { "BufEnter", "CursorMoved", "CursorMovedI", "WinScrolled" },
      { callback = update }
   )
end

function smartcolumn.setup_buffer(conf)
   config.buffer_config[vim.api.nvim_get_current_buf()] = conf
   update()
end

return smartcolumn
