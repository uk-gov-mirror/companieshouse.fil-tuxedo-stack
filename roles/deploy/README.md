# Deploy role

This role implements a sequence of tasks required to deploy Tuxedo FIL services and configuration.

## Table of contents

* [Overview][1]
* [Configuration][2]
    * [Services][3]
        * [SMS poll daemon configuration][4]
        * [SMS service printer configuration][5]
        * [CABS service Oracle DB credentials][6]
    * [Logging][7]
    * [Maintenance jobs][8]
    * [Data directories][9]

[1]: #overview
[2]: #configuration
[3]: #services
[4]: #sms-poll-daemon-configuration
[5]: #sms-service-printer-configuration
[6]: #cabs-service-oracle-db-credentials
[7]: #logging
[8]: #maintenance-jobs
[9]: #data-directories

## Overview

This role encapsulates the tasks required to deploy Tuxedo services to cloud-based hosts.

## Configuration

The following sections detail the different areas of configuration supported by this role.

### Role variables

The following mandatory role variables are required for execution of this role:

| Name                        | Description                                                                                          |
|-----------------------------|------------------------------------------------------------------------------------------------------|
| `tuxedo_service`            | The collective name of the set of services to be deployed; one of `cabs`, `ef`, `prod`, or `scud`.   |
| `environment_name`          | The name of the environment to deploy services to; one of `development`, `staging`, or `live`.       |
| `application_artifact_path` | The path to the [fil-tuxedo](https://github.com/companieshouse/fil-tuxedo) build artefact to deploy. |
| `application_configs_path`  | The path to a directory containing configuration files extracted from a [fil-tuxedo-configs](https://github.com/companieshouse/fil-tuxedo-configs) build artifact. |
| `scripts_artifact_path`     | The path to a directory containing shell scripts extracted from a [fil-tuxedo-scripts](https://github.com/companieshouse/fil-tuxedo-scripts) build artifact.                           |

### Services

Tuxedo services are configured using the `tuxedo_service_config` variable. This variable is defined as a dictionary of dictionaries whose keys represent separate groups of Tuxedo services. Each group corresponds to a Linux user login and provides a level of separation between logically related services (e.g. `cabs`, `ef`, `prod`, `scud`).

> [!NOTE]
>  A default configuration has been provided for the full set of services (`ef`, `prod`, `scud`, and `cabs`); see [defaults/main.yml](defaults/main.yml).

Each dictionary must include the following parameters unless marked _optional_:

| Name                    | Description                                                                           |
|-------------------------|---------------------------------------------------------------------------------------|
| `ipc_key`               | A unique IPC key value for Tuxedo services.                                           |
| `local_domain_port`     | The port number to use for the local Tuxedo domain.                                   |
| `informix_server_name`  | _Optional_. The name of the Informix server that services will access.                |

#### SMS poll daemon configuration

The following variables are used to configure the SMS poll daemon:

> [!NOTE]
> The SMS poll daemon is automatically stopped and started by this role when the `tuxedo_service` is set to `scud`. This is done to ensure that the daemon is not running during a deployment and will be unaffected by the changes.

| Name                         | Default                         | Description                                                                           |
|------------------------------|---------------------------------|---------------------------------------------------------------------------------------|
| `sms_poll_daemon_enabled`    | `false`                         | _Optional_. A boolean value indicating whether the `SMS_poll` daemon should be stopped before deployment and started again after deployment. |
| `sms_poll_daemon_executable` | `SMS_poll`                      | _Optional_. The executable name of the SMS poll daemon process.                       |

#### SMS service printer configuration

Configuration of the printer device used by SMS services is controlled by the variables listed below. The default configuration is suitable for use in development environments where no physical printer is available (i.e. on-disk PDF files will be generated instead). Override the `sms_printer_uri` and `sms_printer_model` variables for other environments that require actual printer support.

| Name                  | Default        | Description                          |
|-----------------------|----------------|--------------------------------------|
| `sms_printer_enabled` | `true`         | A boolean value specifying whether to enable the SMS printer configuration or not. |
| `sms_printer_name`    | `sms-printer`  | The name to be used when adding the CUPS printer configuration. |
| `sms_printer_uri`     | `cups-pdf:/`   | The device URI of the printer queue. |
| `sms_printer_model`   | `CUPS-PDF.ppd` | The path to a PostScript Printer Description (PPD) file. |
| `sms_printer_pdf_output_dir` | `/var/spool/cups-pdf/${USER}` | The output directory for PDF files generated when using the CUPS PDF printer. |

> [!NOTE]
> The following caveats apply to hosts that have already been provisioned by this role and therefore contain existing printer configuration:
>
> - Changing the `sms_printer_enabled` value from `true` to `false` will remove the printer configuration and disable the `cups` and `colord` services
> - Modifying any of the variables above (excluding `sms_printer_enabled`) will not result in changes being made to an existing printer configuration; instead, remove the printer from the host by running `lpadmin -x <printer-name>` first and then execute this role against the host to enact the new configuration

#### CABS service Oracle DB credentials

Oracle DB credentials for the `CABS` service are read from Hashicorp Vault using the path specified by the `cabs_oracle_db_credentials_vault_path` role variable. The secret is expected to contain a JSON object with the following three key-pair values:

```json
{
  "host": "<host>",
  "username": "<username>",
  "password": "<password>"
}
```

### Logging

Log data can be pushed to CloudWatch log groups automatically and is controlled by the `tuxedo_log_files` configuration variable. This variable functions in a manner similar to `tuxedo_service_config` (see [Services][3]), whereby each key represents the configuration for a named group of Tuxedo services, each of which corresponds to a user account on the remote host.

`tuxedo_log_files` should be defined as a dictionary of lists whose keys represent named groups of Tuxedo services (e.g. `cabs`, `ef`, `prod` or `scud`). Each list item represents one or more log files and requires the following parameters:

| Name                        | Description                                                                           |
|-----------------------------|---------------------------------------------------------------------------------------|
| `file_pattern`              | The log file name or a file name pattern to match against. Log files are assumed to reside in `/var/log/tuxedo/<service>` where `<service>` corresponds to the dictionary key under which the list item containing this parameter is defined. |
| `cloudwatch_log_group_name` | The name of the CloudWatch log group that will be used when pushing log data.         |

### Maintenance jobs

The `maintenance_jobs` variable can be used to configure scheduled maintenance jobs. This is used primarily as a group or host variable to configure maintenance jobs specific to environments or individual hosts and is generally limited to the _live_ environment where alerts and statistics are required. The absence of a group variable for a given environment means that _no_ scheduled jobs will be configured.

`maintenance_jobs` should be defined as a dictionary of lists whose keys represent named groups of Tuxedo services (e.g. `cabs`, `ef`, `prod` or `scud`). Each list item represents a single scheduled job for the user matching the dictionary key under which the item is defined. The following parameters are required for each list item:

| Name           | Description                                                                          |
|----------------|--------------------------------------------------------------------------------------|
| `name`         | A description of the job. This parameter should be unique across all jobs defined for a given group. |
| `day_of_week`  | Day of the week that the job should run (`0-6` for Sunday-Saturday, `*`, and so on). |
| `day_of_month` | Day of the month the job should run (`1-31`, `*`, `*/2`, and so on).                 |
| `minute`       | Minute when the job should run (`0-59`, `*`, `*/2`, and so on).                      |
| `hour`         | Hour when the job should run (`0-23`, `*`, `*/2`, and so on).                        |
| `script`       | The name of the script to execute. This should correspond to a script that is present in the [fil-tuxedo-scripts](https://github.com/companieshouse/fil-tuxedo-scripts) artefact being used at the time the role is executed, and is expected to exist in a `scripts/<service>` subdirectory in the expanded artefact, where `<service>` matches the name of the Tuxedo service user for which the script will be deployed (e.g. `cabs`, `ef`, `prod`, `scud`).

For example, to execute the `prod_stats` script at midnight every day as the `prod` user:

```yaml
maintenance_jobs:
  prod:
    - name: Server status alert
      day_of_week: "*"
      day_of_month: "*"
      minute: "0"
      hour: "0"
      script: "prod_stats"
```

During execution of this role, cron jobs are temporarily disabled to avoid generating false positive email alerts and are enabled again before completion of the role.

### Data directories

The `data_directories` variable can be used to create additional service-specific directories for the storage of files. This is used primarily as a group or host variable.

`data_directories` should be defined as a dictionary of lists whose keys represent named groups of Tuxedo services (e.g. `cabs`, `ef`, `prod` or `scud`). Each list item represents a single directory for which the following parameters are required:

| Name                 | Default | Description                          |
|----------------------|---------|--------------------------------------|
| `name`               |         | The name of the directory to create. |
| `mode`               | `0755`  | The permissions the directory should have (as used by the [file](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/file_module.html) module). |

For example, to create a `fiche` directory for `scud` user services:

```yaml
data_directories:
  scud:
    - name: fiche
```

The resulting directory will be created at the path `/home/scud/fiche` with `scud` user and group ownership, and default `0755` permissions.
