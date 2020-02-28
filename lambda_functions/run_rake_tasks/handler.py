import os
import boto3

ecs = boto3.client("ecs")
codepipeline = boto3.client("codepipeline")


def handler(event, context):
    rake_tasks = os.getenv("RAKE_TASKS", "db:migrate").split(",")
    for task in rake_tasks:
        run(task, event)


def run(task, event):
    subnet = os.environ["subnet_id"]
    security_groups = os.environ["security_group_ids"]
    task_name = os.environ["task_name"]
    task_definition = os.environ["task_definition"]
    cluster_name = os.environ["cluster_name"]
    function_name = os.environ["AWS_LAMBDA_FUNCTION_NAME"]

    network_config = {
        "awsvpcConfiguration": {
            "subnets": [subnet],
            "securityGroups": security_groups.split(","),
            "assignPublicIp": "DISABLED",
        }
    }

    overrides = {"containerOverrides": [{"name": task_name, "command": ["rake", task]}]}

    response = ecs.run_task(
        cluster=cluster_name,
        taskDefinition=task_definition,
        launchType="FARGATE",
        startedBy=function_name[0:36],
        networkConfiguration=network_config,
        overrides=overrides,
    )

    print(response)

    if response["failures"]:
        codepipeline.put_job_failure_result(
            jobId=event["CodePipeline.job"]["id"],
            failureDetails={
                "message": response["failures"][0]["reason"],
                "type": "JobFailed",
            },
        )
    else:
        codepipeline.put_job_success_result(jobId=event["CodePipeline.job"]["id"])
