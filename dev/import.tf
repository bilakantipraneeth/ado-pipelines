# # This file is temporary and should be deleted after a successful 'terraform apply'.

# # The 'to' address has been updated again. It now points to the resource
# # created inside the for_each loop within our custom 'member_iam' module.
# #
# # The pattern is now:
# # module.<parent_module>["<sa_key>"].module.<inner_module>["<role>"].<resource_type>.<resource_name>["<role>"]

# import {
#   to = module.project_iam_bindings["wif_service_account"].module.member_roles["roles/storage.objectViewer"].google_project_iam_member.member_iam_binding["roles/storage.objectViewer"]

#   # The 'id' field remains the standard for google_project_iam_member.
#   # YOU MUST REPLACE these values with your actual, existing resource details.
#   id = "your-gcp-project-id roles/storage.objectViewer principalSet://iam.googleapis.com/projects/1234567890/locations/global/workloadIdentityPools/my-pool/subject/my-repo-subject"
# }