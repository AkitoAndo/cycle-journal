"""API Stack for CycleJournal."""

from aws_cdk import (
    CfnOutput,
    Duration,
    Stack,
    aws_apigateway as apigw,
    aws_iam as iam,
    aws_lambda as lambda_,
)
from constructs import Construct


class CycleJournalApiStack(Stack):
    """CycleJournal API Stack - API Gateway + Lambda."""

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        stage: str,
        apple_bundle_id: str = "akito-ando.CycleJournal",
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.stage = stage
        self.apple_bundle_id = apple_bundle_id

        # Lambda Layer（JWT依存関係）
        self.jwt_layer = self._create_jwt_layer()

        # Lambda関数
        self.health_function = self._create_health_function()
        self.coach_function = self._create_coach_function()
        self.auth_function = self._create_auth_function()
        self.authorizer_function = self._create_authorizer_function()

        # Lambda Authorizer（一時的に無効化 - トークン更新機能実装後に有効化）
        # self.api_authorizer = self._create_api_authorizer()

        # API Gateway
        self.api = self._create_api_gateway()

        # 出力
        CfnOutput(
            self,
            "ApiUrl",
            value=self.api.url,
            description="API Gateway URL",
        )

    def _create_health_function(self) -> lambda_.Function:
        """ヘルスチェック用Lambda関数を作成."""
        return lambda_.Function(
            self,
            "HealthFunction",
            function_name=f"cyclejournal-{self.stage}-health",
            runtime=lambda_.Runtime.PYTHON_3_12,
            handler="health.handler",
            code=lambda_.Code.from_asset("../src/handlers"),
            timeout=Duration.seconds(10),
            memory_size=128,
            environment={
                "STAGE": self.stage,
            },
        )

    def _create_coach_function(self) -> lambda_.Function:
        """コーチ用Lambda関数を作成."""
        fn = lambda_.Function(
            self,
            "CoachFunction",
            function_name=f"cyclejournal-{self.stage}-coach",
            runtime=lambda_.Runtime.PYTHON_3_12,
            handler="coach.handler",
            code=lambda_.Code.from_asset("../src/handlers"),
            timeout=Duration.seconds(60),
            memory_size=512,
            environment={
                "STAGE": self.stage,
                "BEDROCK_MODEL_ID": "anthropic.claude-3-haiku-20240307-v1:0",
            },
        )

        # Bedrock呼び出し権限を付与
        fn.add_to_role_policy(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=[
                    "bedrock:InvokeModel",
                    "bedrock:InvokeModelWithResponseStream",
                ],
                resources=[
                    f"arn:aws:bedrock:ap-northeast-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
                ],
            )
        )

        return fn

    def _create_jwt_layer(self) -> lambda_.LayerVersion:
        """JWT依存関係のLambda Layerを作成."""
        return lambda_.LayerVersion(
            self,
            "JwtLayer",
            layer_version_name=f"cyclejournal-{self.stage}-jwt-layer",
            code=lambda_.Code.from_asset("../src/layers/jwt"),
            compatible_runtimes=[lambda_.Runtime.PYTHON_3_12],
            description="PyJWT and cryptography for Apple Sign In",
        )

    def _create_auth_function(self) -> lambda_.Function:
        """認証検証用Lambda関数を作成."""
        return lambda_.Function(
            self,
            "AuthFunction",
            function_name=f"cyclejournal-{self.stage}-auth",
            runtime=lambda_.Runtime.PYTHON_3_12,
            handler="auth.handler",
            code=lambda_.Code.from_asset("../src/handlers"),
            layers=[self.jwt_layer],
            timeout=Duration.seconds(30),
            memory_size=256,
            environment={
                "STAGE": self.stage,
                "APPLE_BUNDLE_ID": self.apple_bundle_id,
            },
        )

    def _create_authorizer_function(self) -> lambda_.Function:
        """Lambda Authorizer用関数を作成."""
        return lambda_.Function(
            self,
            "AuthorizerFunction",
            function_name=f"cyclejournal-{self.stage}-authorizer",
            runtime=lambda_.Runtime.PYTHON_3_12,
            handler="authorizer.handler",
            code=lambda_.Code.from_asset("../src/handlers"),
            layers=[self.jwt_layer],
            timeout=Duration.seconds(10),
            memory_size=256,
            environment={
                "STAGE": self.stage,
                "APPLE_BUNDLE_ID": self.apple_bundle_id,
            },
        )

    def _create_api_authorizer(self) -> apigw.TokenAuthorizer:
        """API Gateway用のToken Authorizerを作成."""
        return apigw.TokenAuthorizer(
            self,
            "AppleTokenAuthorizer",
            authorizer_name=f"cyclejournal-{self.stage}-apple-authorizer",
            handler=self.authorizer_function,
            results_cache_ttl=Duration.minutes(5),
        )

    def _create_api_gateway(self) -> apigw.RestApi:
        """API Gatewayを作成."""
        api = apigw.RestApi(
            self,
            "CycleJournalApi",
            rest_api_name=f"cyclejournal-{self.stage}-api",
            description="CycleJournal API",
            deploy_options=apigw.StageOptions(
                stage_name=self.stage,
                throttling_rate_limit=100,
                throttling_burst_limit=200,
            ),
            default_cors_preflight_options=apigw.CorsOptions(
                allow_origins=apigw.Cors.ALL_ORIGINS,
                allow_methods=apigw.Cors.ALL_METHODS,
                allow_headers=["Content-Type", "Authorization"],
            ),
        )

        # /health エンドポイント（認証不要）
        health = api.root.add_resource("health")
        health.add_method(
            "GET",
            apigw.LambdaIntegration(self.health_function),
        )

        # /auth エンドポイント（認証不要）
        auth = api.root.add_resource("auth")
        auth_verify = auth.add_resource("verify")
        auth_verify.add_method(
            "POST",
            apigw.LambdaIntegration(self.auth_function),
        )

        # /coach エンドポイント（一時的に認証なし - トークン更新機能実装後に認証を追加）
        coach = api.root.add_resource("coach")
        coach.add_method(
            "POST",
            apigw.LambdaIntegration(self.coach_function),
        )

        return api
