# 📚 Tokyo Turntable

A web based app used to help people find shows and venues in Tokyo
<br>

![IMG_7754](https://github.com/user-attachments/assets/94530789-2281-419f-99d2-00dd5ee572ab)

Landing page 
![IMG_7755](https://github.com/user-attachments/assets/5ccbc90f-31b8-48a0-9820-fe3f813c860d)

<br>
App home: tokyoturntable.com
   

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
I'd like to thank the owner of https://www.tokyogigguide.com for having built such an incredible website that hosts almost every venue in Tokyo. His website was vital in helping us to build our webpage.

## Team Members
- William Sebastian https://github.com/MaddRussian
- Ryan Ward https://github.com/Ward-R
- Hikari Hashiguchi https://github.com/hikari-h

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
This project is licensed under the MIT License
