local function initialize()
	global.rules = global.rules or {}
end

function create_fagc_popup(admin, suspect)
	if admin.gui.screen["fagc_frame_" .. suspect] ~= nil then
		admin.gui.screen["fagc_frame_" .. suspect].destroy()
	end
	local frame = admin.gui.screen.add{type="frame", name="fagc_frame_" .. suspect, caption="Factorio Anti-Griefer Coordination", direction="vertical"}
	frame.style="dialog_frame"
	frame.auto_center = true
	frame.style.bottom_padding = 2
	create_fagc_suspect_offences(frame, suspect)

	create_fagc_buttons(frame)
	
end

function create_fagc_suspect_offences(parent, suspect)
	if parent ~= nil and parent.valid then
		
		local fagc_offence_frame = parent.add{type="frame", direction="vertical", name="fagc_offence_frame"}
		fagc_offence_frame.style = "inside_deep_frame"
		fagc_offence_frame.style.width = 388
		fagc_offence_frame.style.left_padding = 0
		fagc_offence_frame.style.right_padding = 0
		fagc_offence_frame.style.top_padding = 2
		fagc_offence_frame.style.horizontal_align = "center"
		
		local suspect_label = fagc_offence_frame.add{type="label", caption="Reporting: " .. suspect, name="fagc_suspect_label"}
		suspect_label.style = "info_label"
		suspect_label.style.font = "heading-1"
		suspect_label.style.left_padding = 16
		suspect_label.style.bottom_padding = 1

		local offences_parent = fagc_offence_frame.add{type="scroll-pane", direction="vertical", name="fagc_offences_parent", vertical_scroll_policy="always", horizontal_scroll_policy="never"}
		offences_parent.style.maximal_height = 300
		offences_parent.style.padding = 0
		
		local offences = offences_parent.add{type="flow", direction="vertical", name="fagc_offences"}
		offences.style.minimal_width = 380
		offences.style.vertical_spacing = 0
		
		create_fagc_rules(offences)
		
	end
end

function create_fagc_rules(parent)
	if parent ~= nil and parent.valid and parent.name == "fagc_offences" then
		for i,rule in pairs(global.rules) do
			local button = parent.add{type="button", name=rule.id, caption=rule.id, tooltip=rule.l}
			button.style = "list_box_item"
			button.style.horizontally_stretchable = true
			button.style.horizontal_align = "left"
			button.style.width = 370
			button.style.height = 28
			if rule.id < 10 then
				button.style.left_padding = 16
			end
			button.caption = button.caption .. " : " .. rule.s
			if rule.s == "Legacy" then
				button.style = "red_button"
				button.enabled = false
				button.caption = button.caption .. " (Not allowed)"
			end
		end
	end
end

function create_fagc_buttons(parent)
	if parent ~= nil and parent.valid then
		local button_frame = parent.add{type="flow", direction="horizontal", name="fagc_button_frame"}
		button_frame.style.padding = 4
		
		local cancel = button_frame.add {type="button", caption="Cancel", name="fagc_cancel"}
		cancel.style = "red_back_button"
		
		local useless = button_frame.add {type="empty-widget", name="fagc_useless"}
		useless.style = "draggable_space"
		useless.style.horizontally_stretchable = true
		useless.style.vertically_stretchable = true
		
		local report = button_frame.add {type="button", caption="Report", name="fagc_report"}
		report.style = "confirm_double_arrow_button"
		report.style.width = 165
	end
end

function toggle_fagc_offence(element)
	if element ~= nil and element.valid and element.type == "button" then
		if element.style.name == "highlighted_tool_button" then
			element.style = "list_box_item"
			element.style.font = "default"
		else
			element.style = "highlighted_tool_button"
			element.style.font = "default-bold"
		end
	end
end

function write_report(admin, element)
	if element ~= nil and element.valid and element.type == "button" and element.parent ~= nil and element.parent.name == "fagc_button_frame" then
		local parent = element.parent
		if parent.parent ~= nil and parent.parent.valid then
			local top = parent.parent
			local suspect = string.gsub(top.name, "fagc_frame_", "")
			if top.fagc_offence_frame ~= nil and top.fagc_offence_frame.valid then
				local to = top.fagc_offence_frame
				if to.fagc_offences_parent ~= nil and to.fagc_offences_parent.valid then
					local t = to.fagc_offences_parent
					if t.fagc_offences ~= nil and t.fagc_offences.valid then
						local container  = t.fagc_offences
						local offences = ""
						local valid = false
						for i, child in pairs(container.children_names) do
							if container[child].style.name == "highlighted_tool_button" then
								valid = true
								offences = offences .. tonumber(child) .. ", "
							end
						end
						if valid then
							offences = string.sub(offences, 1, -3)
							local line = admin .. "~" .. suspect .. "~" .. offences
							game.write_file("fagc.txt", "REPORT~" .. line .. "~\n", true, 0)
							top.destroy()
						else
							game.players[admin].print("You must select atleast one rule")
						end
					end
				end
			end
		end
	end
end

script.on_init(function()
    initialize()
end)

script.on_event(defines.events.on_console_command, function(event)
	if event.player_index == nil then return end
	local p = game.players[event.player_index]
	if p.admin then
		if event.command == "ban" then
			local suspect = ""
			for argument in string.gmatch(event.parameters, "%S+") do
				if suspect == "" then
					suspect = argument
				end
			end
			if suspect ~= nil and suspect ~= "" then
				create_fagc_popup(p, suspect)
			end
		end
	end
end)

script.on_event(defines.events.on_gui_click, function(e)
	if e.player_index == nil then return end
	local p = game.players[e.player_index]
	local el = e.element
	if el.valid and p.admin and el.parent ~= nil then
		if el.parent.name == "fagc_offences" then
			toggle_fagc_offence(el)
		elseif el.parent.name == "fagc_button_frame" then
			if el.name == "fagc_cancel" then
				el.parent.parent.destroy()
			elseif el.name == "fagc_report" then
				write_report(p.name, el)
			end
		end
	end
end)

remote.remove_interface("fagc")
remote.add_interface("fagc", {
	clearRules = function()
		global.rules = {}
	end,
	setRule = function(id, s, l)
		global.rules[tonumber(id)] = {id=tonumber(id), s=s, l=l}
	end,
	createPopup = function(admin, suspect)
		local p = game.players[admin]
		if p ~= nil and p.admin then
			create_fagc_popup(p, suspect)
		end
	end
})