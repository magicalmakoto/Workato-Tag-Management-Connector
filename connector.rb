{
	title: 'Workato Tag Management',

	connection: {
		fields: [
			{
				name: 'data_center',
				label: 'Data center',
				control_type: 'select',
				optional: false,
				# Connection fields can't reference pick_lists, so the hosts are listed inline.
				options: [
					['US', 'www.workato.com'],
					['EU', 'app.eu.workato.com'],
					['JP', 'app.jp.workato.com'],
					['SG', 'app.sg.workato.com'],
					['AU', 'app.au.workato.com'],
					['IL', 'app.il.workato.com'],
					['CN', 'app.workatoapp.cn'],
					['KR', 'app.kr.workato.com'],
					['UK', 'app.uk.workato.com'],
					['Self-service (Free, Pro, Developer Sandbox)', 'app.trial.workato.com']
				],
				hint: 'The data center that hosts your Workato workspace.'
			},
			{
				name: 'api_token',
				label: 'API token',
				control_type: 'password',
				optional: false,
				hint: 'Create an API client in <b>Workspace admin > API clients</b>. ' \
					'Its client role needs the tag endpoints under Environment management ' \
					'and the tag assignments endpoint.'
			}
		],

		authorization: {
			type: 'custom_auth',

			apply: lambda do |connection|
				headers('Authorization' => "Bearer #{connection['api_token']}")
			end
		},

		# Request paths in this connector have no leading slash, so they keep the /api/ prefix.
		base_uri: lambda do |connection|
			"https://#{connection['data_center']}/api/"
		end
	},

	# List tags is the one endpoint every client role for this connector has to allow.
	test: lambda do |_connection|
		get('tags', per_page: 1)
	end,

	custom_action: true,

	custom_action_help: {
		learn_more_url: 'https://docs.workato.com/en/workato-api',
		learn_more_text: 'Workato Developer API documentation',
		body: '<p>Build your own Workato Developer API action with an HTTP request. ' \
			'The request is authorized with this connection. Paths are relative to ' \
			'<b>/api/</b>, so enter <b>tags</b> rather than <b>/api/tags</b>.</p>'
	},

	actions: {
		create_tag: {
			title: 'Create tag',
			subtitle: 'Create a tag in your Workato workspace',

			description: lambda do |_input, _picklist_label|
				"Create <span class='provider'>tag</span> in <span class='provider'>Workato</span>"
			end,

			input_fields: lambda do |object_definitions, _connection, _config_fields|
				object_definitions['tag_input'].required('title')
			end,

			execute: lambda do |_connection, input|
				response = post('tags', call('tag_payload', input)).
					after_error_response(/.*/) do |code, body, _headers, message|
						error(call('api_error_message', code, body, message))
					end
				response['data']
			end,

			output_fields: lambda do |object_definitions, _connection, _config_fields|
				object_definitions['tag'].only('handle', 'title', 'description', 'color')
			end,

			sample_output: lambda do |_connection, _input|
				call('sample_tag').slice('handle', 'title', 'description', 'color')
			end
		},

		delete_tag: {
			title: 'Delete tag',
			subtitle: 'Delete a tag from your Workato workspace',

			description: lambda do |_input, _picklist_label|
				"Delete <span class='provider'>tag</span> in <span class='provider'>Workato</span>"
			end,

			input_fields: lambda do |object_definitions, _connection, _config_fields|
				object_definitions['tag_handle']
			end,

			# A successful delete returns 200 with no body, so the output is built here.
			execute: lambda do |_connection, input|
				delete("tags/#{input['handle']}").
					after_error_response(/.*/) do |code, body, _headers, message|
						error(call('api_error_message', code, body, message))
					end.
					after_response do |_code, _body, _headers|
						{ success: true, handle: input['handle'] }
					end
			end,

			output_fields: lambda do |_object_definitions, _connection, _config_fields|
				[
					{ name: 'success', type: 'boolean' },
					{ name: 'handle' }
				]
			end,

			sample_output: lambda do |_connection, _input|
				{ success: true, handle: call('sample_tag')['handle'] }
			end
		},

		# Search tags can already do this with blank filters, but nobody looks for "list" under "search".
		list_tags: {
			title: 'List tags',
			subtitle: 'Get all tags in your Workato workspace',

			description: lambda do |_input, _picklist_label|
				"List <span class='provider'>tags</span> in <span class='provider'>Workato</span>"
			end,

			help: 'Returns every tag in the workspace, with its author and assignment count. ' \
				'To filter or sort the results, use <b>Search tags</b>.',

			input_fields: lambda do |_object_definitions, _connection, _config_fields|
				[]
			end,

			execute: lambda do |_connection, _input|
				{ tags: call('list_tags', {}) }
			end,

			output_fields: lambda do |object_definitions, _connection, _config_fields|
				[
					{ name: 'tags', type: 'array', of: 'object', properties: object_definitions['tag'] }
				]
			end,

			sample_output: lambda do |_connection, _input|
				{ tags: [call('sample_tag')] }
			end
		},

		manage_tag_assignments: {
			title: 'Manage tag assignments',
			subtitle: 'Add tags to or remove tags from recipes and connections',

			description: lambda do |_input, picklist_label|
				"#{picklist_label['operation'] || 'Manage'} on " \
					"<span class='provider'>#{picklist_label['asset_type']&.downcase || 'assets'}</span> " \
					"in <span class='provider'>Workato</span>"
			end,

			help: 'The API can tag recipes and connections only. Select what to do and which ' \
				'assets to change. The matching fields are then required.',

			# The API needs at least one tag list and at least one ID list, but the schema has no
			# "one of" rule. Choosing the operation and asset type first lets each field be required.
			config_fields: [
				{
					name: 'operation',
					label: 'Operation',
					control_type: 'select',
					optional: false,
					pick_list: [
						['Add tags', 'add'],
						['Remove tags', 'remove'],
						['Add and remove tags', 'add_remove']
					]
				},
				{
					name: 'asset_type',
					label: 'Assets',
					control_type: 'select',
					optional: false,
					pick_list: [
						['Recipes', 'recipes'],
						['Connections', 'connections'],
						['Recipes and connections', 'both']
					]
				}
			],

			input_fields: lambda do |object_definitions, _connection, _config_fields|
				object_definitions['tag_assignment_input']
			end,

			execute: lambda do |_connection, input|
				payload = {
					add_tags: call('split_list', input['add_tags']),
					remove_tags: call('split_list', input['remove_tags']),
					recipe_ids: call('to_id_list', input['recipe_ids'], 'Recipe IDs'),
					connection_ids: call('to_id_list', input['connection_ids'], 'Connection IDs')
				}.compact
				# Required fields still accept a datapill that turns out empty at runtime.
				if payload.slice(:add_tags, :remove_tags).empty? || payload.slice(:recipe_ids, :connection_ids).empty?
					error('Provide at least one tag and at least one recipe or connection ID.')
				end
				# A successful assignment returns 200 with no body, so the output echoes the request.
				post('tags_assignments', payload).
					after_error_response(/.*/) do |code, body, _headers, message|
						error(call('api_error_message', code, body, message))
					end.
					after_response do |_code, _body, _headers|
						{ success: true }.merge(payload)
					end
			end,

			output_fields: lambda do |_object_definitions, _connection, _config_fields|
				[
					{ name: 'success', type: 'boolean' },
					{ name: 'add_tags', label: 'Added tags', type: 'array', of: 'string' },
					{ name: 'remove_tags', label: 'Removed tags', type: 'array', of: 'string' },
					{ name: 'recipe_ids', label: 'Recipe IDs', type: 'array', of: 'integer' },
					{ name: 'connection_ids', label: 'Connection IDs', type: 'array', of: 'integer' }
				]
			end,

			sample_output: lambda do |_connection, _input|
				{
					success: true,
					add_tags: [call('sample_tag')['handle']],
					recipe_ids: [12345],
					connection_ids: [67890]
				}
			end
		},

		search_tags: {
			title: 'Search tags',
			subtitle: 'Find tags in your Workato workspace',

			description: lambda do |_input, _picklist_label|
				"Search <span class='provider'>tags</span> in <span class='provider'>Workato</span>"
			end,

			help: 'Returns every tag that matches the filters. Leave all filters blank to return all tags.',

			input_fields: lambda do |object_definitions, _connection, _config_fields|
				object_definitions['tag_search_input']
			end,

			execute: lambda do |_connection, input|
				{ tags: call('list_tags', call('search_params', input)) }
			end,

			output_fields: lambda do |object_definitions, _connection, _config_fields|
				[
					{ name: 'tags', type: 'array', of: 'object', properties: object_definitions['tag'] }
				]
			end,

			sample_output: lambda do |_connection, _input|
				{ tags: [call('sample_tag')] }
			end
		},

		update_tag: {
			title: 'Update tag',
			subtitle: 'Change the title, description, or color of a tag',

			description: lambda do |_input, _picklist_label|
				"Update <span class='provider'>tag</span> in <span class='provider'>Workato</span>"
			end,

			help: 'Fields you leave blank keep their current values.',

			input_fields: lambda do |object_definitions, _connection, _config_fields|
				object_definitions['tag_handle'] + object_definitions['tag_input']
			end,

			execute: lambda do |_connection, input|
				# PUT requires a title, and the docs don't say whether omitted fields are cleared.
				# Starting from the current tag keeps every value the user left blank.
				current = call('fetch_tag', input['handle']).slice('title', 'description', 'color').compact
				response = put("tags/#{input['handle']}", current.merge(call('tag_payload', input))).
					after_error_response(/.*/) do |code, body, _headers, message|
						error(call('api_error_message', code, body, message))
					end
				response['data']
			end,

			output_fields: lambda do |object_definitions, _connection, _config_fields|
				object_definitions['tag'].only('handle', 'title', 'description', 'color')
			end,

			sample_output: lambda do |_connection, _input|
				call('sample_tag').slice('handle', 'title', 'description', 'color')
			end
		}
	},

	object_definitions: {
		tag: {
			fields: lambda do |_connection, _config_fields, _object_definitions|
				[
					{ name: 'handle' },
					{ name: 'title' },
					{ name: 'description' },
					{ name: 'color' },
					{ name: 'created_at', type: 'date_time' },
					{ name: 'updated_at', type: 'date_time' },
					{
						name: 'author',
						type: 'object',
						properties: [
							{ name: 'id', label: 'Author ID', type: 'integer' },
							{ name: 'name' },
							{ name: 'avatar_url', label: 'Avatar URL' }
						]
					},
					{ name: 'assignment_count', type: 'integer' }
				]
			end
		},

		# Only the fields that match the selected operation and asset type are shown.
		tag_assignment_input: {
			fields: lambda do |_connection, config_fields, _object_definitions|
				operation = config_fields['operation']
				assets = config_fields['asset_type']
				[
					(call('tag_list_field', 'add_tags', 'Tags to add', false) if %w[add add_remove].include?(operation)),
					(call('tag_list_field', 'remove_tags', 'Tags to remove', false) if %w[remove add_remove].include?(operation)),
					(call('id_list_field', 'recipe_ids', 'Recipe IDs') if %w[recipes both].include?(assets)),
					(call('id_list_field', 'connection_ids', 'Connection IDs') if %w[connections both].include?(assets))
				].compact
			end
		},

		tag_handle: {
			fields: lambda do |_connection, _config_fields, _object_definitions|
				[
					{
						name: 'handle',
						label: 'Tag',
						control_type: 'select',
						pick_list: 'tags',
						optional: false,
						toggle_hint: 'Select tag',
						toggle_field: {
							name: 'handle',
							label: 'Tag handle',
							type: 'string',
							control_type: 'text',
							optional: false,
							toggle_hint: 'Use tag handle',
							hint: 'For example, <b>tag-ANgdXgTF-bANz3H</b>.'
						}
					}
				]
			end
		},

		tag_input: {
			fields: lambda do |_connection, _config_fields, _object_definitions|
				[
					{ name: 'title', sticky: true, hint: 'Maximum of 30 characters.' },
					{ name: 'description', sticky: true, hint: 'Maximum of 150 characters.' },
					{
						name: 'color',
						control_type: 'select',
						pick_list: 'tag_colors',
						sticky: true,
						hint: 'Workato picks a random color when you create a tag without one.',
						toggle_hint: 'Select color',
						toggle_field: {
							name: 'color',
							label: 'Color',
							type: 'string',
							control_type: 'text',
							toggle_hint: 'Use color name',
							hint: 'One of: blue, violet, green, red, orange, gold, indigo, brown, teal, plum, slate, neutral.'
						}
					}
				]
			end
		},

		tag_search_input: {
			fields: lambda do |_connection, _config_fields, _object_definitions|
				[
					{ name: 'query', label: 'Title or description contains', sticky: true },
					call('tag_list_field', 'handles', 'Tags', true),
					{ name: 'author_id', label: 'Author ID', type: 'integer', convert_input: 'integer_conversion' },
					{ name: 'recipe_id', label: 'Recipe ID', type: 'integer', convert_input: 'integer_conversion' },
					{ name: 'connection_id', label: 'Connection ID', type: 'integer', convert_input: 'integer_conversion' },
					{
						name: 'only_assigned',
						label: 'Only assigned tags',
						type: 'boolean',
						control_type: 'checkbox',
						convert_input: 'boolean_conversion',
						toggle_hint: 'Select from list',
						toggle_field: {
							name: 'only_assigned',
							label: 'Only assigned tags',
							type: 'string',
							control_type: 'text',
							toggle_hint: 'Use custom value',
							hint: 'Enter <b>true</b> or <b>false</b>.'
						}
					},
					{
						name: 'sort_by',
						control_type: 'select',
						pick_list: [
							['Title', 'title'],
							['Assignment count', 'assignment_count'],
							['Updated at', 'updated_at'],
							['Last assigned at', 'last_assigned_at']
						]
					},
					{
						name: 'sort_direction',
						control_type: 'select',
						pick_list: [['Ascending', 'asc'], ['Descending', 'desc']]
					}
				]
			end
		}
	},

	pick_lists: {
		tag_colors: lambda do |_connection|
			%w[blue violet green red orange gold indigo brown teal plum slate neutral].
				map { |color| [color.capitalize, color] }
		end,

		tags: lambda do |_connection|
			call('list_tags', {}).map { |tag| [tag['title'], tag['handle']] }
		end
	},

	methods: {
		# Workato returns {"errors": [{"code", "title", "detail"}]}. Fall back to the raw body
		# when the response isn't in that shape, such as an HTML error page from a proxy.
		api_error_message: lambda do |code, body, message|
			errors = begin
				parse_json(body)['errors']
			rescue StandardError
				nil
			end
			details = Array.wrap(errors).map { |item| [item['title'], item['detail']].compact.join(' - ') }.join('; ')
			"#{code} #{message}: #{details.presence || body}"
		end,

		# The API has no "get one tag" endpoint, so this filters List tags by handle.
		fetch_tag: lambda do |handle|
			tag = call('list_tags', { q: { handle_in: [handle] } }).first
			tag.presence || error("No tag found with handle #{handle}.")
		end,

		id_list_field: lambda do |name, label|
			{
				name: name,
				label: label,
				optional: false,
				hint: 'Comma-separated IDs, for example <b>12345,67890</b>.'
			}
		end,

		# List tags returns no total or next-page marker, so a short page means the last page.
		list_tags: lambda do |params|
			page_size = 100
			tags = []
			page = 1
			loop do
				response = get('tags', params.merge(page: page, per_page: page_size, includes: %w[author assignment_count])).
					after_error_response(/.*/) do |code, body, _headers, message|
						error(call('api_error_message', code, body, message))
					end
				batch = response.dig('data', 'tags') || []
				tags.concat(batch)
				break if batch.size < page_size

				page += 1
			end
			tags
		end,

		# Matches the List tags sample response in the Workato docs.
		sample_tag: lambda do
			{
				'handle' => 'tag-ANgdXgTF-bANz3H',
				'title' => 'Accounting',
				'description' => 'Accounting tag',
				'color' => 'orange',
				'created_at' => '2024-08-29T14:09:13-07:00',
				'updated_at' => '2024-08-29T14:09:13-07:00',
				'author' => { 'id' => 12345, 'name' => 'Charlie', 'avatar_url' => '' },
				'assignment_count' => 6
			}
		end,

		search_params: lambda do |input|
			q = {
				title_or_description_cont: input['query'].presence,
				handle_in: call('split_list', input['handles']),
				author_id_eq: input['author_id'],
				recipe_id_eq: input['recipe_id'],
				connection_id_eq: input['connection_id'],
				# Sending false would only repeat the default, so the filter is left out instead.
				only_assigned: (true if input['only_assigned'].to_s == 'true')
			}.compact
			{
				q: q.presence,
				sort_by: input['sort_by'].presence,
				sort_direction: input['sort_direction'].presence
			}.compact
		end,

		# Handles both the multiselect value ("a,b") and a typed or mapped comma-separated list.
		split_list: lambda do |value|
			Array.wrap(value).flat_map { |item| item.to_s.split(',') }.map(&:strip).reject(&:blank?).presence
		end,

		tag_list_field: lambda do |name, label, optional|
			{
				name: name,
				label: label,
				control_type: 'multiselect',
				pick_list: 'tags',
				delimiter: ',',
				optional: optional,
				sticky: true,
				toggle_hint: 'Select tags',
				toggle_field: {
					name: name,
					label: "#{label} (handles)",
					type: 'string',
					control_type: 'text',
					optional: optional,
					toggle_hint: 'Use tag handles',
					hint: 'Comma-separated tag handles, for example <b>tag-ANgdXgTF-bANz3H,tag-ANgef8oT-TgTeFY</b>.'
				}
			}
		end,

		# Blank fields are dropped so they don't overwrite values with empty strings.
		tag_payload: lambda do |input|
			input.slice('title', 'description', 'color').reject { |_key, value| value.blank? }
		end,

		# Rejects anything that isn't a whole number, because "abc".to_i would silently become 0.
		to_id_list: lambda do |value, label|
			ids = call('split_list', value)
			if ids.present?
				invalid = ids.reject { |id| id.match?(/\A\d+\z/) }
				error("#{label} must be whole numbers. Invalid values: #{invalid.join(', ')}") if invalid.present?
				ids.map(&:to_i)
			end
		end
	}
}
