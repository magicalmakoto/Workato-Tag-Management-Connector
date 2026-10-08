# Workato Tag Management Connector

A Workato custom connector for the tag endpoints of the Workato Developer API.  This was created as the native RecipeOps connector allows some actions to be filter to recipes with certain tags, but has no way to see what tags exist on recipes outside the trigger, or other ways to do automatic tag management.

## Actions

| Action | Endpoint |
| --- | --- |
| List tags | `GET /api/tags` |
| Search tags | `GET /api/tags` |
| Create tag | `POST /api/tags` |
| Update tag | `PUT /api/tags/:handle` |
| Delete tag | `DELETE /api/tags/:handle` |
| Manage tag assignments | `POST /api/tags_assignments` |
| Custom action | Any Developer API endpoint |

## Install

### Create the API client

1. Go to **Workspace admin > API clients > Client roles**.
2. Create a role with the tag endpoints under Environment management and the tag assignments endpoint.
3. Go to **API clients > Create API client**.
4. Assign the role and the projects the connector can reach.
5. Copy the API token. Workato shows it once.

### Add the connector

1. Go to **Tools > Connector SDK**.
2. Select **New connector**.
3. Paste the contents of `connector.rb` into the code editor.
4. Save the connector.

### Connect

1. Create a connection that uses **Workato Tag Management**.
2. Select your data center.
3. Paste the API token.

The connection test calls `GET /api/tags?per_page=1`.

## Behavior notes

### Update tag

The API requires a title on every update and has no endpoint that gets one tag. The action looks up the current tag first, then sends your changes over its values. Fields you leave blank keep their current values. The action counts as one Workato task.

### Manage tag assignments

The API tags recipes and connections only. Choose the operation and asset type first. The action then shows only the matching fields and marks them required.

The action also checks the values at runtime, because a required field can still map to an empty datapill.

Workato array fields hold objects, not plain values. Tag handles and IDs are comma-separated text for that reason.

### Search tags

The action reads every page and returns all matches. List tags returns no total, so a page with fewer than 100 tags ends the search.

## Limits

These are the Connector SDK quotas that apply to this connector.

| Quota | Limit |
| --- | --- |
| HTTP request timeout in the Test code console | 40 seconds |
| HTTP request timeout in a job | 3 minutes |
| Compile timeout | 5 seconds |
| Connector code size | 10 MB |

The Developer API rate limits were not available when this connector was written. Check the rate limits on the Workato Developer API pages.

## Source documentation

- [Developer API](https://docs.workato.com/en/workato-api)
- [Environment management](https://docs.workato.com/en/workato-api/environment-management)
- [Tag assignments](https://docs.workato.com/en/workato-api/tag-assignments)
- [API clients and roles](https://docs.workato.com/en/workato-api/api-clients)
- [Connector SDK](https://docs.workato.com/en/developing-connectors/sdk)

## License

MIT. See `LICENSE`.
