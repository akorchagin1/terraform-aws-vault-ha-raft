data "aws_iam_policy_document" "snapshots_sts" {
  count = var.aws_snapshots ? 1 : 0

  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "snapshots" {
  count = var.aws_snapshots ? 1 : 0

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ec2:CreateSnapshot",
      "ec2:DeleteSnapshot",
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["arn:aws:ec2:*::snapshot/*"]
    actions = [
      "ec2:CreateTags",
    ]
  }
}

resource "aws_iam_role" "snapshots" {
  count = var.aws_snapshots ? 1 : 0

  name               = format(local.name_tmpl, "dlm-snapshots")
  assume_role_policy = data.aws_iam_policy_document.snapshots_sts[0].json
}

resource "aws_iam_role_policy" "snapshots" {
  count = var.aws_snapshots ? 1 : 0

  name   = format(local.name_tmpl, "dlm-snapshots")
  role   = aws_iam_role.snapshots[0].id
  policy = data.aws_iam_policy_document.snapshots[0].json
}

resource "aws_dlm_lifecycle_policy" "snapshots" {
  count = var.aws_snapshots ? 1 : 0

  description        = format(local.name_tmpl, "snapshots")
  execution_role_arn = aws_iam_role.snapshots[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = format("%dh %ds %s snapshots",
        var.aws_snapshots_interval,
        var.aws_snapshots_retain,
        replace(var.aws_snapshots_time, ":", "-")
      )

      create_rule {
        interval      = var.aws_snapshots_interval
        interval_unit = "HOURS"
        times         = [var.aws_snapshots_time]
      }

      retain_rule {
        count = var.aws_snapshots_retain
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
      }

      copy_tags = true
    }

    target_tags = {
      Snapshot = "true"
    }
  }

  tags = merge(local.tags, {
    Name = format(local.name_tmpl, "snapshots")
  })
}
