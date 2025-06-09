# 🎧 Tokyo Turntable

A Ruby on Rails application which helps users find live shows around Tokyo which suit their music preferences.

![image](https://github.com/user-attachments/assets/f712527e-270e-4c19-8d46-a01eb3107c7e)

<br>
App home: https://WHATEVER.herokuapp.com
   

## Getting Started
### Setup

Install gems
```
bundle install
```

### ENV Variables
Create `.env` file
```
touch .env
```
Inside `.env`, set these variables. For any APIs, see group Slack channel.
```
CLOUDINARY_URL=your_own_cloudinary_url_key
```

### DB Setup
```
rails db:create
rails db:migrate
rails db:seed
```

### Run a server
```
rails s
```

## Built With
- [Rails 7](https://guides.rubyonrails.org/) - Backend / Front-end
- [Stimulus JS](https://stimulus.hotwired.dev/) - Front-end JS
- [Heroku](https://heroku.com/) - Deployment
- [PostgreSQL](https://www.postgresql.org/) - Database
- [Bootstrap](https://getbootstrap.com/) — Styling
- [Figma](https://www.figma.com) — Prototyping

## Acknowledgements
Thanks to Tokyo Gig Guide, we were able to scrape the data from close to 1000 live music venues around Tokyo and get information about upcoming shows.

## Team Members
- Ryan Ward, Julian Schoenfeld, Hikari Hashiguchi

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
This project is licensed under the MIT License
