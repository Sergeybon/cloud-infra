323957640402.dkr.ecr.eu-central-1.amazonaws.com/frontend-repository-prod:latest

[
    {
        "name": "${workspace}-backend-service",
        "image": "${image_repository_path}:${workspace}-latest",
        "memory": 2048,
        "essentials": true,
        "portMappings": [
            {
            "containerPort": ${backend_port},
            "hostPort": ${backend_port}
            }
        ],
        "logConfiguration": {
            "logDriver": "awslogs",
            "options": {
                "awslogs-group": "awslogs-backend",
                "awslogs-region": "eu-central-1",
                "awslogs-stream-prefix": "awslogs-backend"
            }
        },
        "environment": [
            {
                "name": "DB_HOST",
                "value": "${database_host}"
            },
            {
                "name": "DB_NAME",
                "value": "${database_name}"
            },
            {
                "name": "DB_PASSWORD",
                "value": "${database_password}"
            },
            {
                "name": "DB_USER",
                "value": "${database_user}"
            },
            {
                "name": "GOOGLE_CLIENT_ID",
                "value": "${google_client_id}"
            },
            {
                "name": "GOOGLE_CLIENT_SECRET",
                "value": "${google_client_secret}"
            },
            {
                "name": "NODE_ENV",
                "value": "development"
            },
            {
                "name": "FRONTEND_URL",
                "value": "https://${env}${frontend_url}"
            }
        ]
    }
]
