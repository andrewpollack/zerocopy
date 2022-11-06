#!/bin/bash
#
# Copyright 2022 The Fuchsia Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Usage: `pkg-meta <selector> <crate-name> <manifest-path>`
#
# Extract metadata from zerocopy's `Cargo.toml` file.
function pkg-meta {
    if [[ $# != 3 ]]; then
        echo "Usage: pkg-meta <selector> <crate-name> <manifest-path>" >&2
        return 1
    fi
    cargo metadata --manifest-path $3 --format-version 1 | jq -r ".packages[] | select(.name == \"$2\").$1"
}

# Usage: `msrv <crate-name> <manifest-path>`
#
# Extract the `rust_version` package metadata key.
function msrv {
    if [[ $# != 2 ]]; then
        echo "Usage: msrv <crate-name> <manifest-path>" >&2
        return 1
    fi
    pkg-meta rust_version $1 $2
}

# Usage: `version <crate-name> <manifest-path>`
#
# Extract the `version` mackage metadata key.
function version {
    if [[ $# != 2 ]]; then
        echo "Usage: version <crate-name> <manifest-path>" >&2
        return 1
    fi
    pkg-meta version $1 $2
}

function test_check_fmt {
    ROOT=$(git rev-parse --show-toplevel)                              && \
    cargo fmt --check --manifest-path $ROOT/Cargo.toml                 && \
    cargo fmt --check --manifest-path $ROOT/zerocopy-derive/Cargo.toml && \
    rustfmt --check $ROOT/tests/ui/*.rs                                && \
    rustfmt --check $ROOT/zerocopy-derive/tests/ui/*.rs
}

function test_check_readme {
    ROOT=$(git rev-parse --show-toplevel)            && \
    cargo install cargo-readme --version 3.2.0       && \
    diff <($ROOT/generate-readme.sh) $ROOT/README.md
}

function test_check_msrvs {
    path_zerocopy=Cargo.toml
    path_zerocopy_derive=zerocopy-derive/Cargo.toml

    ROOT=$(git rev-parse --show-toplevel)                            && \
    ver_zerocopy=$(msrv zerocopy $ROOT/$path_zerocopy)               && \
    ver_zerocopy_derive=$(msrv zerocopy $ROOT/$path_zerocopy_derive) && \

    if [[ "$ver_zerocopy" == "$ver_zerocopy_derive" ]]; then
        echo "Same MSRV ($ver_zerocopy) found in '$path_zerocopy' and '$path_zerocopy_derive'."
        true
    else
        echo "Different MSRVs found in '$path_zerocopy' ($ver_zerocopy) and '$path_zerocopy_derive' ($ver_zerocopy_derive)."
        false
    fi
}

function test_check_versions {
    path_zerocopy=Cargo.toml
    path_zerocopy_derive=zerocopy-derive/Cargo.toml

    ROOT=$(git rev-parse --show-toplevel)                                      && \
    ver_zerocopy=$(version zerocopy $ROOT/$path_zerocopy)                      && \
    ver_zerocopy_derive=$(version zerocopy-derive $ROOT/$path_zerocopy_derive) && \
    zerocopy_derive_dep_ver=$(cargo metadata --manifest-path Cargo.toml --format-version 1 \
            | jq -r ".packages[] | select(.name == \"zerocopy\").dependencies[] | select(.name == \"zerocopy-derive\").req") && \
    
    if [[ "$ver_zerocopy" == "$ver_zerocopy_derive" ]]; then
        echo "Same crate version ($ver_zerocopy) found in '$path_zerocopy' and '$path_zerocopy_derive'."
    else
        echo "Different crate versions found in '$path_zerocopy' ($ver_zerocopy) and '$path_zerocopy_derive' ($ver_zerocopy_derive)."
        false
    fi && \

    # Note the leading `=` sign - the dependency needs to be an exact one.
    if [[ "=$ver_zerocopy_derive" == "$zerocopy_derive_dep_ver" ]]; then
        echo "zerocopy depends upon same version of zerocopy-derive in-tree ($zerocopy_derive_dep_ver)."
    else
        echo "zerocopy depends upon different version of zerocopy-derive ($zerocopy_derive_dep_ver) than the one in-tree ($ver_zerocopy_derive)."
        false
    fi
}
