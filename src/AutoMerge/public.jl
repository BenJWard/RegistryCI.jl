function run(env = ENV,
             cicfg::CIService=auto_detect_ci_service(;env=env);
             merge_new_packages::Bool,
             merge_new_versions::Bool,
             new_package_waiting_period,
             new_jll_package_waiting_period,
             new_version_waiting_period,
             new_jll_version_waiting_period,
             registry::String,
             authorized_authors::Vector{String},
             #
             additional_statuses::AbstractVector{<:AbstractString} = String[],
             additional_check_runs::AbstractVector{<:AbstractString} = String[],
             #
             master_branch::String = "master",
             master_branch_is_default_branch::Bool = true,
             suggest_onepointzero::Bool = true)::Nothing
    all_statuses = deepcopy(additional_statuses)
    all_check_runs = deepcopy(additional_check_runs)
    push!(all_statuses, "automerge/decision")
    unique!(all_statuses)
    unique!(all_check_runs)

    registry_head = directory_of_cloned_registry(cicfg; env=env)

    # Run tests on the registry (these are very quick)
    RegistryCI.test(registry_head)

    # Figure out what type of build this is
    run_pr_build = conditions_met_for_pr_build(cicfg; env=env, master_branch=master_branch)
    run_merge_build = conditions_met_for_merge_build(cicfg; env=env, master_branch=master_branch)

    if !(run_pr_build || run_merge_build)
        throw(AutoMergeWrongBuildType("Build not determined to be either a PR build or a merge build. Exiting."))
    end

    # Authentication
    auth = my_retry(() -> GitHub.authenticate(env["AUTOMERGE_GITHUB_TOKEN"]))
    whoami = my_retry(() -> username(cicfg; auth=auth))
    @info("Authenticated to GitHub as \"$(whoami)\"")
    registry_repo = my_retry(() -> GitHub.repo(registry; auth=auth))

    if run_pr_build
        pr_number = pull_request_number(cicfg; env=env)
        pr_head_commit_sha = current_pr_head_commit_sha(cicfg; env=env)
        pull_request_build(pr_number,
                           pr_head_commit_sha,
                           registry_repo,
                           registry_head;
                           auth = auth,
                           authorized_authors = authorized_authors,
                           master_branch = master_branch,
                           master_branch_is_default_branch = master_branch_is_default_branch,
                           suggest_onepointzero = suggest_onepointzero,
                           whoami = whoami)
        return nothing
    else
        always_assert(run_merge_build)
        cron_or_api_build(registry_repo;
                          auth = auth,
                          authorized_authors = authorized_authors,
                          merge_new_packages = merge_new_packages,
                          merge_new_versions = merge_new_versions,
                          new_package_waiting_period = new_package_waiting_period,
                          new_jll_package_waiting_period = new_jll_package_waiting_period,
                          new_version_waiting_period = new_version_waiting_period,
                          new_jll_version_waiting_period = new_jll_version_waiting_period,
                          whoami = whoami,
                          all_statuses = all_statuses,
                          all_check_runs = all_check_runs)
        return nothing
    end
end
