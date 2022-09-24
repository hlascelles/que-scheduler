# Description

Please include a summary of the change and which issue is fixed. Please also include relevant
motivation and context. List any dependencies that are required for this change.

Fixes # (issue)

## Type of change

Please delete options that are not relevant.

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] This change requires a documentation update

# How Has This Been Tested?

You should be able to run the full test suite locally.

In one terminal, run a postgres docker container:

```bash
docker run -p 5430:5432 postgres:9.6.0
```

In another, run the full test suite (takes about 30 seconds)

```bash
./appraisal.sh
```
