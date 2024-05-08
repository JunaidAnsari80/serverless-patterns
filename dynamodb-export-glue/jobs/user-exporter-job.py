import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.dynamicframe import DynamicFrame

args = getResolvedOptions(sys.argv, ['JOB_NAME','DEST_FOLDER'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Script generated for node AWS Glue Data Catalog
AWSGlueDataCatalog_node1711372916921 = glueContext.create_dynamic_frame.from_catalog(database="user-exporter-catalog-db", table_name="user-exporter-eatalog-db-table", transformation_ctx="AWSGlueDataCatalog_node1711372916921")

# Script generated for node Autobalance Processing
AutobalanceProcessing_node1711372960445 = AWSGlueDataCatalog_node1711372916921.toDF().repartition(10)
#AutobalanceProcessing_node1711372960445 = AWSGlueDataCatalog_node1711372916921.gs_repartition(numPartitionsStr="10")

# Script generated for node Amazon S3

AmazonS3_node1711373212477 = glueContext.write_dynamic_frame.from_options(frame=DynamicFrame.fromDF(AutobalanceProcessing_node1711372960445, glueContext, 'user-index-df'), connection_type="s3", format="glueparquet", connection_options={"path": "s3://"+ args['DEST_FOLDER'] +"/", "partitionKeys": []}, format_options={"compression": "uncompressed"}, transformation_ctx="AmazonS3_node1711373212477")

job.commit()