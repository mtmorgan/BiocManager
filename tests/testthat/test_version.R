context("version()")

test_that("version is package_version class", {
    expect_s3_class(version(), "package_version")
    expect_s3_class(version(), "numeric_version")
})

test_that("version has two components", {
    verNums <- strsplit(as.character(version()), "\\.")[[1L]]
    expect_identical(length(verNums), 2L)
})

test_that(".version_validate() validates version", {
    .version_validate <- BiocManager:::.version_validate

    expect_error(
        .version_validate("2.0"),
        "Bioconductor version '2.0' requires R version '2.5'; .*"
    )

    expect_error(
        .version_validate("1.2.3"),
        "version '1.2.3' must have two components, e.g., '3.7'"
    )

    expect_error(
        .version_validate("100.1"),
        "unknown Bioconductor version '100.1'; .*"
    )
})

test_that(".version_recommend() recommends update", {
    expect_true(startsWith(
        .version_recommend("2.0"),
        "Bioconductor version '2.0' is out-of-date"
    ))
})

test_that(".version_validity_online_check() works", {
    ## environment variable
    withr::with_options(list(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS=NULL), {
        withr::with_envvar(c(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS=NA), {
            expect_identical(.version_validity_online_check(), TRUE)
        })

        withr::with_envvar(c(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS=TRUE), {
            expect_identical(.version_validity_online_check(), TRUE)
        })

        withr::with_envvar(c(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS=FALSE), {
            expect_identical(.version_validity_online_check(), FALSE)
        })
    })

    ## options
    withr::with_envvar(c(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS=NA), {
        withr::with_options(list(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS=NULL), {
            expect_identical(.version_validity_online_check(), TRUE)
        })
    })

    withr::with_options(list(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS=TRUE), {
        expect_identical(.version_validity_online_check(), TRUE)

        ## prefer option to env
        withr::with_envvar(c(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS=FALSE), {
            expect_identical(.version_validity_online_check(), TRUE)
        })
    })

    withr::with_options(list(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS=FALSE), {
        expect_identical(.version_validity_online_check(), FALSE)

        ## prefer option to env
        withr::with_envvar(c(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS=TRUE), {
            expect_identical(.version_validity_online_check(), FALSE)
        })
    })
})

test_that(".version_validity('devel') works", {
    devel <- .version_bioc("devel")
    if (version() == devel) {
        expect_true(.version_validity("devel"))
    } else {
        test <- paste0("Bioconductor version '", devel, "' requires R version")
        expect_true(startsWith(.version_validity("devel"), test))
    }
})

test_that(".version_validity() and BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS work",{
    withr::with_options(list(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS=FALSE), {
        expect_match(
            .version_validity("1.2"),
            "unknown Bioconductor version '1.2'; .*"
        )
    })
})

test_that(".version_validate() and BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS work",{
    withr::with_options(list(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS=FALSE), {
        expect_error(
            .version_validate("1.2"),
            "unknown Bioconductor version '1.2'; .*"
        )
    })
})


test_that(".version_map_get() and BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS work",{
    withr::with_options(list(BIOCONDUCTOR_ONLINE_VERSION_DIAGNOSIS=FALSE), {
        value <- .version_map_get()
        if ("BiocVersion" %in% rownames(installed.packages()))
            expect_identical(packageVersion("BiocVersion")[, 1:2], value[1, 1])
        else
            expect_identical(value, .VERSION_MAP_SENTINEL)
    })
})

test_that(".version_map_get() falls back to http", {
    ## better test ideas welcome...
    url <- "https://httpbin.org/status/404"
    msgs <- list()
    result <- withCallingHandlers({
        .version_map_get(url)
    }, warning = function(w) {
        msgs <<- c(msgs, list(w))
        invokeRestart("muffleWarning")
    })
    ## did we generate warnings and eventually fail gracefully?
    expect_identical(length(msgs), 2L)
    expect_true(all(vapply(msgs, is, logical(1), "simpleWarning")))
    msgs <- vapply(msgs, conditionMessage, character(1))
    expect_identical(sum(grepl("https://httpbin.org", msgs)), 1L)
    expect_identical(sum(grepl("http://httpbin.org", msgs)), 1L)
    expect_identical(result, .VERSION_MAP_SENTINEL)
})
