local smartcolumn = {}

local config = {
   colorcolumn = "80",
   disabled_filetypes = { "help", "text", "markdown" },
   custom_colorcolumn = {},
   scope = "file",
   editorconfig = true,
   buffer_config = {},
   custom_autocommand = false,
}

-- Check if the current line exceeds the colorcolumn
---@param buf number: buffer number
---@param win number: window number
---@param min_colorcolumn number?: minimum colorcolumn
local function exceed(buf, win, min_colorcolumn)
   if vim.tbl_contains(config.disabled_filetypes, vim.bo.ft) then return false end

   if not min_colorcolumn then
      return false
   end
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

   for _, line in pairs(lines) do
      local success, column_number = pcall(vim.fn.strdisplaywidth, line)

      if not success then
         return false
      end

      if column_number > min_colorcolumn then return true end
   end

   return false
end

local function colorcolumn_editorconfig(colorcolumns)
   return vim.b[0].editorconfig
         and vim.b[0].editorconfig.max_line_length ~= "off"
         and vim.b[0].editorconfig.max_line_length
      or colorcolumns
end

local function update(buf)
   local buf_filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
   local colorcolumns

   if vim.tbl_contains(config.disabled_filetypes, buf_filetype) then
      return
   end

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

   -- if not min_colorcolumn then
   --    return
   -- end

   local wins = vim.api.nvim_list_wins()
   for _, win in pairs(wins) do
      local win_buf = vim.api.nvim_win_get_buf(win)
      if win_buf == current_buf then
         local current_state = exceed(win_buf, win, min_colorcolumn)
         if current_state ~= vim.b.prev_state then
            vim.b.prev_state = current_state
            if current_state then
               if type(colorcolumns) == "table" then
                  vim.wo[win].colorcolumn = table.concat(colorcolumns, ",")
               else
                  vim.wo[win].colorcolumn = colorcolumns
               end
            else
               vim.wo[win].colorcolumn = ""
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

   if config.custom_autocommand then
      return
   end

   local group = vim.api.nvim_create_augroup("SmartColumn", {})
   vim.api.nvim_create_autocmd(
      { "BufEnter", "CursorMoved", "CursorMovedI", "WinScrolled" },
      {
         group = group,
         callback = update,
      }
   )
end

function smartcolumn.setup_buffer(buf, conf)
   config.buffer_config[buf] = conf
   update(buf)
end

return smartcolumn
