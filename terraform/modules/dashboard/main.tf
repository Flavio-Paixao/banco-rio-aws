# Painel unico com as duas regioes. Um dashboard vive numa regiao, mas cada grafico
# informa de qual regiao le a metrica.

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-resiliencia"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# Resiliencia do banco ficticio\nProjeto de estudo. Os graficos so tem dados se a infraestrutura for criada (o projeto e validado apenas com plan)."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "Aurora Global: atraso de replicacao (ms)"
          region = var.dr_region
          view   = "timeSeries"
          stat   = "Maximum"
          period = 60
          metrics = [
            ["AWS/RDS", "AuroraGlobalDBReplicationLag", "DBClusterIdentifier", var.aurora_secondary_cluster_id]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "Route 53: status do health check da primaria (1 = saudavel)"
          region = "us-east-1"
          view   = "timeSeries"
          stat   = "Minimum"
          period = 60
          metrics = [
            ["AWS/Route53", "HealthCheckStatus", "HealthCheckId", var.health_check_id]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "ALB primario: erros 5xx do balanceador"
          region = var.primary_region
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.primary_alb_arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "ALB de DR: erros 5xx do balanceador"
          region = var.dr_region
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.dr_alb_arn_suffix]
          ]
        }
      },
    ]
  })
}
