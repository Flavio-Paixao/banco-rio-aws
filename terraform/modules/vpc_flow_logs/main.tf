data "aws_caller_identity" "current" {}

# O nome do log group comeca com /<projeto>/, padrao que a key policy da chave de logs aceita.
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/${var.project_name}/${var.region_label}/vpc-flow-logs"
  retention_in_days = var.retention_in_days
  kms_key_id        = var.kms_key_arn

  tags = {
    Name = "${var.project_name}-${var.region_label}-vpc-flow-logs"
  }
}

# Role que o servico de Flow Logs assume para gravar no log group.
# A condicao impede que outra conta use esta role (problema do "confused deputy").
data "aws_iam_policy_document" "assume" {
  statement {
    sid     = "FlowLogsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  # IAM e global: o nome inclui o rotulo da regiao para nao colidir entre as duas instancias
  name               = "${var.project_name}-${var.region_label}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = {
    Name = "${var.project_name}-${var.region_label}-vpc-flow-logs"
  }
}

data "aws_iam_policy_document" "write_logs" {
  #checkov:skip=CKV_AWS_356:logs:DescribeLogGroups e uma chamada de conta e nao aceita recurso especifico (DECISIONS D-12)
  statement {
    sid       = "WriteToFlowLogGroup"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = [aws_cloudwatch_log_group.flow_logs.arn, "${aws_cloudwatch_log_group.flow_logs.arn}:*"]
  }

  statement {
    sid       = "DescribeLogGroups"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "write-flow-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.write_logs.json
}

resource "aws_flow_log" "vpc" {
  vpc_id               = var.vpc_id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn

  tags = {
    Name = "${var.project_name}-${var.region_label}-vpc-flow-log"
  }
}
