# WMF maps spike
## Instructions
``` sh
$ make help
vendor                         Fetch vendored dependencies
docker_build                   Build docker images
docker_pull                    Pull docker images
bootstrap_env                  Prepare environment variables
run_services                   Bring services up
bootstrap                      Download pbf and load data using imposm3
```

To bring up the stack:

``` sh
$ make run_services
```

To populate with data:

``` sh
$ make bootstrap
```
