# Week 4 – CI/CD & Pipeline Automation

## Objectives

- Understand the principles of CI (Continuous Integration) and CD (Continuous Deployment)
- Create and run multi-stage pipelines with GitHub Actions
- Integrate automated testing and linting into CI workflows
- Understand artifacts and build dependencies
- Implement a basic deployment pipeline
- Practice using version control (Git) for collaborative development

## Estimated Time

⏱️ **2.5-3.5 hours**

## Prerequisites

- GitHub account
- Git installed locally
- Knowledge of basic Linux commands

---

## 1. What is CI/CD?

### Continuous Integration (CI)
The practice of merging developer code into a shared repository several times a day. Each merge is verified by an automated build and tests.
- **Goal**: Catch bugs early, improve code quality.

### Continuous Deployment (CD)
The practice of automatically deploying code to a production environment after it passes the CI stage.
- **Goal**: Release new features quickly and reliably.

---

## 2. Hands-On: GitHub Actions Foundations

GitHub Actions is a CI/CD platform that allows you to automate your build, test, and deployment pipeline.

### Task 1: Create your first workflow
Create a file `.github/workflows/main.yml` in your repository:
```yaml
name: Hello CI
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Say Hello
        run: echo "Hello, world!"
      - name: Run a multi-line script
        run: |
          echo "Building application..."
          ls -R
```

### Task 2: Adding Multi-Stage Build and Test
Update your workflow to include a test job:
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: echo "Compiling..." > build.log
      - uses: actions/upload-artifact@v4
        with:
          name: build-log
          path: build.log

  test:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          name: build-log
      - name: Run tests
        run: |
          cat build.log
          echo "Tests passed!"
```

---

## 3. Real-World Example: Node.js CI

### Task 3: Lint and Test a Node.js App
Create a simple `package.json`:
```json
{
  "name": "tutorial-app",
  "scripts": {
    "test": "echo \"Running tests...\" && exit 0",
    "lint": "echo \"Running linter...\" && exit 0"
  }
}
```

Create a workflow `node-ci.yml`:
```yaml
name: Node.js CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Use Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm install
      - run: npm run lint
      - run: npm test
```

---

## 4. Troubleshooting and Debugging

- **View Logs**: In your GitHub repository, click the **Actions** tab to see running workflows.
- **Debugging**: Add `ACTIONS_STEP_DEBUG: true` to your repository secrets to see detailed step logs.
- **Local Runner**: Explore tools like `act` to run GitHub Actions locally on your machine.

---

## Checklist
- [ ] I can explain the difference between CI and CD.
- [ ] I successfully ran my first GitHub Actions workflow.
- [ ] I understand how to use artifacts to pass data between jobs.
- [ ] I can use the `needs` keyword to define job dependencies.
- [ ] I integrated linting and testing into a pipeline.
