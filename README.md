# Sigma

**Web-Scale Search Engine Made From Scratch**

In active development: https://github.com/berpj/sigma/projects/2

### Features

*To write*

### Technologies

- Ruby
- PHP (web front)
- PostgreSQL
- Redis
- Ubuntu
- Docker (Hub & Cloud)
- AWS EC2
- AWS SQS


### Architecture

![Architecture diagram](https://raw.githubusercontent.com/berpj/sigma/master/diagram.png)

*To write*


### Setup

    git clone https://github.com/berpj/sigma.git
    cd sigma
    docker-compose build
    docker-compose up -d db-development redis-development sqs-development # Start DB, Redis and SQS first
    docker-compose up -d

This last command is going to pull somes images, and build the others. Then it's running: go to http://localhost


### Development

*To write*


### Deployment

*To write*


### References

- http://infolab.stanford.edu/~backrub/google.html
- http://pr.efactory.de/e-pagerank-algorithm.shtml
- http://nlp.stanford.edu/IR-book/html/htmledition/a-first-take-at-building-an-inverted-index-1.html
- http://www.ardendertat.com/category/information-retrieval/
- https://tartarus.org/martin/PorterStemmer/
- https://en.wikipedia.org/wiki/Tf%E2%80%93idf

*To write*
