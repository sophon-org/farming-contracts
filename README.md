# Sophon Farming Contracts
Contracts that enable deposits to farm points.

## Prerequisites
Before running tests and coverage, ensure you have the following installed:

- [node](https://nodejs.org/en/download)
- [foundry](https://book.getfoundry.sh/getting-started/installation)
- [lcov](https://formulae.brew.sh/formula/lcov)
- Create an ```.env``` file from ```.env-sample```

## Installation

Install node modules:
```bash
yarn install
```

## Running Tests

To run tests use the following command:

```bash
forge test
```

## Coverage Report

Generate the report by running:

```bash
forge coverage --report lcov && \
lcov --remove lcov.info -o lcov.info \
'contracts/mocks/*' \
'contracts/farm/test/*' \
'contracts/zap/*' \
'test/*' \
&& genhtml -o report --branch-coverage lcov.info
```

Coverage file is ```lcov.info``` and in the ```report``` directory, the file ```index.html``` is the one to visualize the report.

*The report excludes out of scope contracts.*

## License
UNLICENSED