## arena-compose-postgres

This application consists of a frontend and a backend service, a PostgreSQL database, and a connector proxy, all orchestrated with Docker Compose.

### Services and Default Ports:

- `spiffworkflow-frontend`: The frontend user interface for the workflow application.
- `spiffworkflow-backend`: The backend service providing API endpoints for the frontend.
- `spiffdb`: A PostgreSQL database service used by the backend to store workflow data.
- `spiffworkflow-connector`: A connector proxy service for external integrations.

### Getting Started:

1. Ensure Docker and Docker Compose are installed on your system.
2. Clone the repository and navigate to the directory containing the `docker-compose.yml` file. The default ports are set in this file, but you can change them if needed.
3. Run `make up` to start all services. The services will be available on the following default ports:
4. Access the frontend at `http://localhost:8001`, where `8001` is the default port for the frontend service.
5. Access the backend API at `http://localhost:8000/v1.0`, where `8000` is the default port for the backend service.
6. Run `make down` to stop all services.

### Database Access:

To access the PostgreSQL database from within the `spiffdb` container, use the following command:

```sh
psql -U spiffuser -d spiffworkflow
```

The default username is `spiffuser` and the password is `spiffpass`, as configured in the `docker-compose.yml` file.

### Health Checks:

Health checks are configured for the `spiffworkflow-backend` and `spiffdb` services to ensure they are ready before dependent services start.

## Interacting with the API

The api is available at localhost:8000/v1.0 if you run `make up` in this repo.
This example uses an approval process to show how to navigate tasks that need to wait for human interaction.
To get an idea of how the process works, you might want to view the diagram and run the process at http://localhost:8001/process-models/approvals:basic-approval before hammering the API.

Some of the followiong commands use `jq`, a useful tool for parsing JSON, in case you want to follow along with that by installing it.

```sh
# use a little script to get a token from the nonproduction openid server built in to spiffworkflow-backend and store it in a file.
# note that spiffworkflow supports any openid system, and this built in server should never be used in production.
./bin/get_token admin > /tmp/t

# create a process instance
curl -s -X POST localhost:8000/v1.0/process-instances/approvals:basic-approval -H "Authorization: Bearer $(cat /tmp/t)"

# let's assume that the previous request returned id 24. run that instance
curl -s -X POST localhost:8000/v1.0/process-instances/approvals:basic-approval/24/run -H "Authorization: Bearer $(cat /tmp/t)"

# it requires some human interaction. fetch the tasks that might need completing
curl -s "localhost:8000/v1.0/tasks?process_instance_id=24" -H "Authorization: Bearer $(cat /tmp/t)" | jq .

# the tasks API will return json like this:
# {
#   "results": [
#     {
#       "id": "64c3738c-0dc1-48f6-98fc-7db41e03dab3",
#       "form_file_name": "request-schema.json",
#       "task_type": "UserTask",
#       "ui_form_file_name": "request-uischema.json",
#       "task_status": "READY",
#       [SNIP]
#       "assigned_user_group_identifier": null,
#       "potential_owner_usernames": "admin@spiffworkflow.org"
#     }
#   ],
# }

# it looks like this task uses the request-schema.json form. let's fetch it.
curl -s "localhost:8000/v1.0/process-models/approvals:basic-approval/files/request-schema.json" -H "Authorization: Bearer $(cat /tmp/t)" | jq -r .file_contents

# this response tells us that we need a request_item when submitting the task

# submit the task based on the information from the tasks response
curl -X PUT -H 'Content-type: application/json' -d '{"request_item": "apple"}' "localhost:8000/v1.0/tasks/24/64c3738c-0dc1-48f6-98fc-7db41e03dab3" -H "Authorization: Bearer $(cat /tmp/t)" | jq .

# next the process instance will proceed to the approval task.
# its form can be inspected and the task submitted in the same way as above.
# note that normally the same user who started the process instance would not be able to complete the approval,
# but in this case the user whose token we are using is also in the "admin" group,
# so they have access to complete the approval task in the admin lane.
curl -s "localhost:8000/v1.0/process-models/approvals:basic-approval/files/approval-schema.json" -H "Authorization: Bearer $(cat /tmp/t)" | jq -r .file_contents
curl -X PUT -H 'Content-type: application/json' -d '{"is_approved": false, "comments": "looks good to me"}' "localhost:8000/v1.0/tasks/24/f796b2d5-8d7c-423f-ac1a-2cfbc95f4c04" -H "Authorization: Bearer $(cat /tmp/t)" | jq .

# at this point, after the two PUT requests, you can check on the instance,
# and it will hopefully be completed if you said is_approved false
curl -s localhost:8000/v1.0/process-instances/approvals:basic-approval/24 -H "Authorization: Bearer $(cat /tmp/t)" | jq .
```
If you approved it by setting is_approved to `true`, the instance will be waiting on a final manual task that is just giving you a message about how you approved the item.
Hopefully this has been helpful in describing how to access some of the important functionality via the API.

### Troubleshooting:

If you encounter any issues with the services, check the logs using `docker-compose logs`.
